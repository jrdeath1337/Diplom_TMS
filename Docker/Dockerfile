# ============= СТАДИЯ 1: Билдер =============
FROM rocm/dev-ubuntu-22.04:7.2 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Устанавливаем зависимости для сборки и git (понадобится только здесь)
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    wget \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем PyTorch для ROCm 7.2
RUN pip3 install --no-cache-dir \
    torch \
    torchvision \
    torchaudio \
    --index-url https://download.pytorch.org/whl/rocm7.2

# Клонируем ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui
WORKDIR /comfyui

# Устанавливаем зависимости ComfyUI (без --no-cache-dir для кэширования, но потом очистим)
RUN pip3 install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/rocm7.2

# ============= СТАДИЯ 2: Финальный образ =============
FROM rocm/dev-ubuntu-22.04:7.2

# Копируем установленные Python-пакеты из билдера
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Копируем код ComfyUI
COPY --from=builder /comfyui /comfyui

# Устанавливаем только runtime-зависимости (библиотеки OpenGL и т.п.)
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Задаём рабочую директорию
WORKDIR /comfyui

# Открываем порт
EXPOSE 8188

# Переменная для совместимости с вашим GPU
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0

# Запуск ComfyUI
CMD ["python3", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
