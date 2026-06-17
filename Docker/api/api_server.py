# flake8: noqa: E402 E501
#!/usr/bin/env python3
"""
FastAPI-сервис для приёма промптов и проверки статуса задач.
Общается с той же PostgreSQL, куда worker_core.py складывает результаты.
"""

import json
import logging
import os
from datetime import datetime
from typing import Optional

import psycopg2
import psycopg2.extras
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# --------------------------- Config ---------------------------
DB_DSN = os.getenv("DB_DSN")  # Единый DSN из env-файла

# Логирование
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api")

app = FastAPI(title="Hybrid GPU API", version="1.0.0")

from prometheus_fastapi_instrumentator import Instrumentator

instrumentator = Instrumentator().instrument(app)
instrumentator.expose(app)  # создаст эндпоинт /metrics
# Разрешаем запросы от любого источника (для разработки)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------- HTML ---------------------------
from fastapi.responses import HTMLResponse


@app.get("/")
def root():
    return {
        "message": "Hybrid GPU Rendering API",
        "endpoints": {
            "POST /generate": "Create a new image generation task",
            "GET /status/{task_id}": "Check task status and get result",
            "GET /health": "Health check",
        },
        "docs": "/docs",
    }


@app.get("/ui", response_class=HTMLResponse)
def ui():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hybrid GPU Demo</title>
        <style>
            body { font-family: Arial; margin: 40px; }
            input, textarea { width: 300px; margin: 5px 0; }
            button { padding: 10px 20px; }
            #result { margin-top: 20px; }
            img { max-width: 512px; }
        </style>
    </head>
    <body>
        <h2>Generate Image</h2>
        <label>Prompt:</label><br>
        <textarea id="prompt" rows="3">a cat, high quality</textarea><br>
        <label>Negative prompt:</label><br>
        <input id="negative" value="bad quality, blurry"><br>
        <label>Model:</label><br>
        <input id="model" value="dreamshaperXL_lightningDPMSDE.safetensors"><br>
        <label>Steps:</label><br>
        <input id="steps" type="number" value="5" min="1" max="20"><br>
        <label>CFG scale:</label><br>
        <input id="cfg" type="number" step="0.1" value="1.5" min="1" max="10"><br><br>
        <button onclick="generate()">Generate</button>
        <div id="result"></div>
        <script>
            async function generate() {
                const prompt = document.getElementById('prompt').value;
                const negative = document.getElementById('negative').value;
                const model = document.getElementById('model').value;
                const steps = parseInt(document.getElementById('steps').value);
                const cfg = parseFloat(document.getElementById('cfg').value);
                const res = await fetch('/generate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({prompt, negative_prompt: negative, model, steps, cfg})
                });
                const data = await res.json();
                document.getElementById('result').innerHTML = `<p>Task created: ${data.task_id}</p>`;
                checkStatus(data.task_id);
            }
            async function checkStatus(taskId) {
                const resultDiv = document.getElementById('result');
                let statusEl = document.getElementById('status-text');
                if (!statusEl) {
                    statusEl = document.createElement('p');
                    statusEl.id = 'status-text';
                    resultDiv.appendChild(statusEl);
                }
                const res = await fetch(`/status/${taskId}`);
                const task = await res.json();
                if (task.status === 'completed') {
                    statusEl.innerHTML = `Done! <br><img src="${task.result_url}"><br><a href="${task.result_url}" download>⬇ Скачать изображение</a>`;
                } else if (task.status === 'failed') {
                    statusEl.innerHTML = `Error: ${task.error_msg}`;
                } else {
                    statusEl.textContent = `Status: ${task.status}, waiting...`;
                    setTimeout(() => checkStatus(taskId), 3000);
                }
            }
        </script>
    </body>
    </html>
    """
    # --------------------------- Models ---------------------------


class GenerateRequest(BaseModel):
    prompt: str = Field(..., description="Текст позитивного промпта")
    negative_prompt: str = Field(default="", description="Негативный промпт")
    model: str = Field(
        default="dreamshaperXL_lightningDPMSDE.safetensors",
        description="Имя файла модели в /comfyui/models/checkpoints",
    )
    width: int = Field(default=1024, ge=64, le=2048)
    height: int = Field(default=1024, ge=64, le=2048)
    steps: int = Field(default=5, ge=1, le=150)
    cfg: float = Field(default=1.5, ge=1.0, le=30.0)
    seed: int = Field(default=-1, description="Seed (-1 для случайного)")


class TaskStatus(BaseModel):
    task_id: int
    status: str
    result_url: Optional[str] = None
    error_msg: Optional[str] = None
    created_at: str
    updated_at: str


# --------------------------- DB helpers ---------------------------
def get_db():
    return psycopg2.connect(DB_DSN, cursor_factory=psycopg2.extras.DictCursor)


def build_payload(req: GenerateRequest) -> dict:
    """Собирает workflow для SDXL (как в проверенной задаче #5)"""
    import random

    seed = req.seed if req.seed != -1 else random.randint(0, 2**31 - 1)
    return {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": req.model},
        },
        "2": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": req.prompt, "clip": ["1", 1]},
        },
        "3": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": req.width, "height": req.height, "batch_size": 1},
        },
        "4": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": req.steps,
                "cfg": req.cfg,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1,
                "model": ["1", 0],
                "positive": ["2", 0],
                "negative": ["2", 0],  # повторяем позитивный (для упрощения)
                "latent_image": ["3", 0],
            },
        },
        "5": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["4", 0], "vae": ["1", 2]},
        },
        "6": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": "ComfyUI", "images": ["5", 0]},
        },
    }


# --------------------------- Endpoints ---------------------------
@app.post("/generate", response_model=dict)
def create_task(req: GenerateRequest):
    """Принимает промпт, создаёт задачу в БД, возвращает task_id"""
    conn = get_db()
    try:
        payload = build_payload(req)
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO tasks (payload, status, created_at, updated_at) VALUES (%s, 'pending', now(), now()) RETURNING id",
                (json.dumps(payload),),
            )
            task_id = cur.fetchone()[0]
        conn.commit()
        logger.info(f"Task {task_id} created")
        return {"task_id": task_id, "message": "Task queued"}
    except Exception as e:
        conn.rollback()
        logger.exception("Failed to create task")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/status/{task_id}", response_model=TaskStatus)
def get_status(task_id: int):
    """Возвращает статус задачи и ссылку на результат, если готов"""
    conn = get_db()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, status, result_url, error_msg, created_at, updated_at FROM tasks WHERE id = %s",
                (task_id,),
            )
            row = cur.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Task not found")
        return TaskStatus(
            task_id=row["id"],
            status=row["status"],
            result_url=row["result_url"],
            error_msg=row["error_msg"],
            created_at=row["created_at"].isoformat(),
            updated_at=row["updated_at"].isoformat(),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get status")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


@app.post("/register-worker")
def register_worker(ip: str, port: int = 8000):
    """Регистрирует внешний IP воркера как Kubernetes Service worker-metrics"""
    try:
        from kubernetes import client, config

        config.load_incluster_config()
        v1 = client.CoreV1Api()

        service_name = "worker-metrics"
        namespace = "default"

        # Пробуем найти сервис
        try:
            svc = v1.read_namespaced_service(service_name, namespace)
            # Обновляем IP в endpoint'е (через создание/обновление Endpoints напрямую)
            # Проще заменить сервис полностью или создать/обновить Endpoints
            # Создаем/обновляем Endpoints
            endpoints = client.V1Endpoints(
                metadata=client.V1ObjectMeta(name=service_name, namespace=namespace),
                subsets=[
                    client.V1EndpointSubset(
                        addresses=[client.V1EndpointAddress(ip=ip)],
                        ports=[client.V1EndpointPort(port=port)],
                    )
                ],
            )
            try:
                v1.replace_namespaced_endpoints(service_name, namespace, endpoints)
            except:
                v1.create_namespaced_endpoints(namespace, endpoints)
        except:
            # Сервиса нет, создаем headless сервис и endpoints
            service = client.V1Service(
                metadata=client.V1ObjectMeta(name=service_name, namespace=namespace),
                spec=client.V1ServiceSpec(
                    cluster_ip="None",  # headless
                    ports=[client.V1ServicePort(port=port, target_port=port)],
                ),
            )
            v1.create_namespaced_service(namespace, service)
            endpoints = client.V1Endpoints(
                metadata=client.V1ObjectMeta(name=service_name, namespace=namespace),
                subsets=[
                    client.V1EndpointSubset(
                        addresses=[client.V1EndpointAddress(ip=ip)],
                        ports=[client.V1EndpointPort(port=port)],
                    )
                ],
            )
            v1.create_namespaced_endpoints(namespace, endpoints)

        logger.info(f"Worker registered: {ip}:{port}")
        return {"status": "ok", "message": f"Worker {ip}:{port} registered"}
    except Exception as e:
        logger.exception("Failed to register worker")
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------- Main ---------------------------
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("api_server:app", host="0.0.0.0", port=8888, reload=True)
