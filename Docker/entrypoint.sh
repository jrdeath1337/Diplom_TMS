#!/bin/bash
set -e

# Запускаем ComfyUI в фоне (с явным указанием CPU)
cd /comfyui
python3 main.py --listen 0.0.0.0 --port 8188 --output-directory /comfyui/output --cpu &
COMFY_PID=$!

# Ждём, пока ComfyUI поднимется
echo "Waiting for ComfyUI..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
        echo "ComfyUI is ready"
        break
    fi
    sleep 2
done

# Устанавливаем зависимости воркера (если не установлены)
pip3 install -q psycopg2-binary boto3 requests
# Запускаем воркер
cd /app
echo "Starting worker..."
exec python3 worker_core.py
