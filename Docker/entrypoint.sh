#!/bin/bash
set -e

if [ "$1" = "auto" ]; then
    echo "Starting ComfyUI in background..."
    python3 main.py --listen 0.0.0.0 --port 8188 --output-directory /comfyui/output &
    COMFY_PID=$!

    # Ждём готовности API
    echo "Waiting for ComfyUI..."
    for i in $(seq 1 30); do
        if curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
            echo "ComfyUI is ready"
            break
        fi
        sleep 2
    done

    echo "Starting worker..."
    exec python3 /app/worker_core.py
else
    # Любая другая команда — например, bash для отладки
    exec "$@"
fi
