#!/usr/bin/env python3
"""
Worker для гибридной системы Yandex Cloud + локальный GPU.
- Забирает задачи из PostgreSQL (таблица tasks, статус pending)
- Отправляет запрос в ComfyUI (http://localhost:8188)
- Ждёт генерации, загружает результат в S3
- Обновляет статус задачи (completed/failed) и сохраняет ссылку на результат
"""

import os
import sys
import time
import json
import logging
import signal
import requests
import psycopg2
import psycopg2.extras
import boto3
from botocore.client import Config

# ========== Конфигурация из переменных окружения ==========
DB_DSN = os.getenv("DB_DSN")                     # postgresql://user:pass@host:6432/db?sslmode=require
S3_BUCKET = os.getenv("S3_BUCKET")               # имя бакета
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "https://storage.yandexcloud.net")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "5"))
COMFYUI_URL = "http://localhost:8188"
COMFYUI_OUTPUT_DIR = "/comfyui/output"
GENERATION_TIMEOUT = int(os.getenv("GENERATION_TIMEOUT", "120"))  # таймаут в секундах

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("worker")

# Флаг для graceful shutdown
shutdown_flag = False

def signal_handler(sig, frame):
    global shutdown_flag
    logger.info("Received shutdown signal, exiting...")
    shutdown_flag = True

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# Инициализация S3 клиента
s3_client = boto3.client(
    "s3",
    endpoint_url=S3_ENDPOINT,
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    config=Config(region_name="ru-central1")
)

def get_db_connection():
    """Создаёт новое соединение с PostgreSQL."""
    return psycopg2.connect(DB_DSN, cursor_factory=psycopg2.extras.DictCursor)

def fetch_pending_task():
    """
    Атомарно забирает задачу со статусом 'pending'.
    Открывает и закрывает соединение внутри, возвращает (task_id, payload) или (None, None).
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, payload
                FROM tasks
                WHERE status = 'pending'
                ORDER BY created_at
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            """)
            row = cur.fetchone()
            if row is None:
                return None, None

            task_id = row["id"]
            payload = row["payload"]
            cur.execute("""
                UPDATE tasks
                SET status = 'processing', updated_at = now()
                WHERE id = %s
            """, (task_id,))
            conn.commit()
            return task_id, payload
    except Exception as e:
        logger.exception("Failed to fetch pending task")
        if conn:
            conn.rollback()
        return None, None
    finally:
        if conn:
            conn.close()

def update_task_status(task_id, status, result_url=None, error_msg=None):
    """Обновляет статус задачи в отдельном соединении."""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE tasks
                SET status = %s, result_url = %s, error_msg = %s, updated_at = now()
                WHERE id = %s
            """, (status, result_url, error_msg, task_id))
            conn.commit()
    except Exception as e:
        logger.exception(f"Failed to update status for task {task_id}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()

def generate_image(payload):
    """
    Отправляет workflow/prompt в ComfyUI и возвращает путь к сгенерированному файлу.
    Payload — JSON, совместимый с ComfyUI API.
    """
    resp = requests.post(f"{COMFYUI_URL}/prompt", json={"prompt": payload}, timeout=30)
    resp.raise_for_status()
    prompt_id = resp.json()["prompt_id"]
    logger.info(f"ComfyUI prompt_id: {prompt_id}")

    # Ожидание завершения генерации
    max_attempts = max(1, GENERATION_TIMEOUT // 2)  # опрос каждые 2 секунды
    for _ in range(max_attempts):
        if shutdown_flag:
            raise RuntimeError("Worker shutdown requested during generation")
        hist_resp = requests.get(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)
        hist_resp.raise_for_status()
        history = hist_resp.json()
        if prompt_id in history:
            outputs = history[prompt_id]["outputs"]
            for node_id, node_out in outputs.items():
                if "images" in node_out and node_out["images"]:
                    image_name = node_out["images"][0]["filename"]
                    # Используем стандартный каталог вывода ComfyUI
                    image_path = os.path.join(COMFYUI_OUTPUT_DIR, image_name)
                    if not os.path.exists(image_path):
                        raise FileNotFoundError(f"Generated file not found: {image_path}")
                    logger.info(f"Generated image: {image_path}")
                    return image_path
        time.sleep(2)

    raise TimeoutError(f"Generation timed out after {GENERATION_TIMEOUT}s for prompt {prompt_id}")

def upload_to_s3(file_path, task_id):
    """Загружает файл в Yandex Object Storage и возвращает публичную ссылку."""
    key = f"results/{task_id}_{int(time.time())}.png"
    extra_args = {"ACL": "public-read"} if "storage.yandexcloud.net" in S3_ENDPOINT else {}
    s3_client.upload_file(file_path, S3_BUCKET, key, ExtraArgs=extra_args)
    url = f"https://{S3_BUCKET}.storage.yandexcloud.net/{key}"
    logger.info(f"Uploaded to S3: {url}")
    return url

def process_task(task_id, payload):
    """Обрабатывает одну задачу: генерация -> S3 -> обновление БД."""
    logger.info(f"Processing task {task_id}")
    try:
        image_path = generate_image(payload)
        s3_url = upload_to_s3(image_path, task_id)
        update_task_status(task_id, "completed", result_url=s3_url)
        logger.info(f"Task {task_id} completed: {s3_url}")
        # Удаляем локальный файл
        try:
            os.unlink(image_path)
        except OSError:
            pass
    except Exception as e:
        logger.exception(f"Task {task_id} failed")
        update_task_status(task_id, "failed", error_msg=str(e))

def main():
    """Главный цикл воркера."""
    logger.info("Worker started, waiting for tasks...")
    while not shutdown_flag:
        task_id, payload = fetch_pending_task()
        if task_id is None:
            # Нет задач — спим
            time.sleep(POLL_INTERVAL)
            continue
        process_task(task_id, payload)
    logger.info("Worker stopped.")

if __name__ == "__main__":
    main()
