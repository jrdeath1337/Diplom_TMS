# Diplom_TMS
Дипломная работа для курса DevOps Engineer
``````
CompfyUI_cloud
├── ansible #Настройка ОС и софта
│   ├── inventort.ini #IP инстанса (генерируется terraform)
│   ├── roles #Роли ansible
│   │   ├── common #База (Docker, пакеты)
│   │   ├── k3s #Установка кластера+GPU плагин
│   │   ├── nvidia #Драйвер GPU + nvidia-container-toolkit
│   │   └── storage #Монтирование S3 или создание папок под ИИ модели
│   └── site.yml #Главный playbook
├── docker #Сборка image
│   └── Dockerfile #CompfyUI на базе NVIDIA CUDA
├── k8s #k8s manifest
│   ├── deployment.yaml #Манифест CompfyUI
│   ├── pvc.yaml #persistentVolumeClaim - тут будут храниться ИИ модели для Compfy
│   └── service.yaml #Доступ к UI (NodePort или LoadBalancer)
├── README.md #Ветрина
├── .github #CI/CD pipeline
│   └── workflows
│       └── main.yml Linting -> Build -> Push -> Deploy
└── terraform #IaC: Поднятие инфраструктуры (железа в облаке)
    ├── main.tf #Основные ресурсы (VM, Network, Disk)
    ├── outputs.tf #IP сервера после создания 
    ├── provider.tf #Настройка провайдера (Пока хз что за облако будет)
    └── variables.tf #Переменные (тип GPU, регион)
``````

# 🖼️ DevOps-проект: Self-hosted AI генератор изображений (ComfyUI) в Kubernetes + Yandex Cloud

## 📌 Описание проекта
Проект представляет собой полностью автоматизированное развёртывание сервиса генерации изображений на базе **ComfyUI** в Kubernetes-кластере.  
Реализован **полный цикл DevOps**:
- Локальная разработка и тестирование на CPU
- Финальный запуск в облаке **Yandex Cloud** с GPU (NVIDIA)
- Инфраструктура как код (**Terraform**)
- Управление конфигурацией (**Ansible**)
- Контейнеризация (**Docker**)
- Оркестрация (**Kubernetes**, Managed Kubernetes от Yandex)
- Непрерывная интеграция и доставка (**GitHub Actions** + self-hosted runner)
- Мониторинг состояния GPU и кластера (**Prometheus**, **Grafana**, **DCGM Exporter**)
- Доступ через интернет с HTTPS и базовой аутентификацией

Цель проекта — продемонстрировать навыки DevOps-инженера, работу с GPU-нагрузками, облачными провайдерами и современным инструментарием.

---

## 🏗️ Архитектура проекта
``````[GitHub] -> push -> GitHub Actions (CI/CD)
|
v
Сборка Docker-образа
|
v
Публикация в Container Registry (Yandex Cloud)
|
v
Деплой в Managed Kubernetes (Yandex Cloud)
|
v
+--------------+--------------+
| |
Ingress/HTTPS Под с ComfyUI
(auth + TLS) (GPU: NVIDIA)
| |
v v
Пользователь Модели из Object Storage
``````

**Компоненты:**
- **ComfyUI** — веб-интерфейс для генерации изображений (модели SDXL и др.)
- **Kubernetes** — Managed Kubernetes от Yandex Cloud, одна GPU-нода (V100/A100)
- **Ingress** — nginx-ingress с cert-manager для HTTPS и basic auth
- **Хранилище моделей** — Object Storage (S3-совместимое) с CSI-драйвером для монтирования в под
- **Мониторинг** — Prometheus Operator + DCGM Exporter + Grafana

---

## 🛠️ Технологический стек

| Категория | Инструменты |
|-----------|-------------|
| **Языки/форматы** | YAML, HCL, Bash, Python (минимум) |
| **Контейнеризация** | Docker |
| **Оркестрация** | Kubernetes (Managed Yandex), k3s (локально) |
| **CI/CD** | GitHub Actions + self-hosted runner |
| **IaC** | Terraform (Yandex Cloud) |
| **Управление конфигурацией** | Ansible |
| **Мониторинг** | Prometheus, Grafana, DCGM Exporter |
| **Сеть и безопасность** | Nginx Ingress, cert-manager, basic auth, Cloudflare Tunnel (опционально) |
| **Облако** | Yandex Cloud (Compute, Managed Kubernetes, Object Storage, Container Registry) |
| **GPU** | NVIDIA (CUDA), драйверы от Yandex |

---

## 📋 Предварительные требования

Для локальной разработки:
- Linux (рекомендуется) или WSL2
- Docker
- kubectl
- k3s (для локального тестирования k8s)
- Ansible
- Terraform
- Аккаунт GitHub
- (Опционально) Аккаунт Yandex Cloud для финала

Для облачного этапа:
- Аккаунт Yandex Cloud с активированным доступом к GPU (квоты)
- Зарегистрированный домен (или подготовка к использованию Cloudflare Tunnel)

---

## 🚀 Локальное развёртывание (CPU-режим)

Этот этап позволяет разрабатывать и тестировать логику без затрат на облако.

### 1. Клонирование репозитория
```bash
git clone https://github.com/<your-username>/comfyui-devops.git
cd comfyui-devops
2. Сборка Docker-образа (CPU-версия)
bash
docker build -f docker/Dockerfile.cpu -t comfyui-cpu:latest .
3. Запуск контейнера для проверки
bash
docker run -p 8188:8188 comfyui-cpu:latest
Открой браузер: http://localhost:8188. Должен загрузиться интерфейс ComfyUI.

4. Настройка локального k3s и деплой
Установи k3s:

bash
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
Примени манифесты (CPU-вариант без GPU):

bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment-cpu.yaml
kubectl apply -f k8s/service.yaml
Проверь, что под запустился:

bash
kubectl get pods -n comfyui
Пробрось порт для доступа:

bash
kubectl port-forward -n comfyui pod/comfyui-xxx 8188:8188
5. Настройка CI/CD (self-hosted runner)
Добавь self-hosted runner в GitHub (Settings → Actions → Runners).

Установи и запусти runner на своей машине.

Пример пайплайна .github/workflows/deploy-local.yaml уже в репозитории (адаптируй под registry).

После пуша в ветку main образ будет собираться и деплоиться в локальный k3s.

☁️ Развёртывание в Yandex Cloud (с GPU)
1. Подготовка облачной инфраструктуры через Terraform
Перейди в папку terraform/ и выполни:

bash
terraform init
terraform plan
terraform apply
Будут созданы:

Сеть и подсеть

Service account с правами

Managed Kubernetes кластер

Нод-группа с GPU (прерываемая ВМ)

Container Registry

Object Storage бакет для моделей

2. Получение доступа к кластеру
bash
yc managed-kubernetes cluster get-credentials gpu-cluster --external
kubectl get nodes  # должна отобразиться GPU-нода
3. Установка CSI-драйвера для S3 (монтирование моделей)
bash
helm repo add csi-s3 https://github.com/ctrox/csi-s3
helm install csi-s3 csi-s3/csi-s3 --set accessKey=<...>,secretKey=<...>,endpoint=https://storage.yandexcloud.net
(Создай секрет и StorageClass по инструкции в /docs/s3-csi.md)

4. Деплой приложения
Используй манифесты из k8s/overlays/production (с запросом GPU, Ingress, PVC).

bash
kubectl apply -k k8s/overlays/production
5. Настройка Ingress и HTTPS
Установи nginx-ingress и cert-manager (через Helm).

Создай Issuer для Let's Encrypt.

Примени Ingress-ресурс с указанием домена и secret для basic auth.

6. Мониторинг
bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
Установи DCGM Exporter для сбора метрик GPU:

bash
helm repo add nvidia https://nvidia.github.io/dcgm-exporter/helm
helm install dcgm-exporter nvidia/dcgm-exporter
Импортируй дашборд GPU в Grafana (ID: 12239).

🔄 CI/CD (GitHub Actions)
Пайплайн автоматически:

Собирает Docker-образ (на основе Dockerfile.production с поддержкой CUDA).

Пушит образ в Yandex Container Registry.

Обновляет deployment в Kubernetes (через kubectl set image или helm upgrade).

Конфигурация лежит в .github/workflows/deploy-production.yaml.
Для переключения между окружениями используется переменная KUBE_CONFIG (секрет GitHub).

📊 Мониторинг
Доступ к Grafana осуществляется через Ingress (с аутентификацией).
Метрики GPU:

Utilisation, температура, память, мощность

Частота ядер и памяти

Алерты могут быть настроены в Prometheus (например, при перегреве GPU).

🔐 Безопасность
Доступ к сервису защищён базовой HTTP-аутентификацией (htpasswd).

HTTPS обеспечивается сертификатами Let's Encrypt.

Секреты (токены, пароли) хранятся в GitHub Secrets и Kubernetes Secrets.

GPU-нода — прерываемая ВМ, что снижает стоимость, но требует осторожности.

💰 Экономия бюджета
На этапе разработки всё запускается локально (бесплатно).

В облаке используется прерываемая GPU-ВМ, которая автоматически останавливается ночью (скрипт в scripts/stop-cluster.sh).

Object Storage и Container Registry тарифицируются за хранение — копейки.

Важно: не забывай выключать кластер, когда не работаешь!
Можно настроить автоматическое выключение по расписанию через Yandex Functions.

🧪 Как тестировать
Локально (CPU): быстрая проверка изменений, отладка манифестов, CI/CD.

В облаке (GPU): финальное тестирование производительности, работы GPU, мониторинга.

📈 Планы по улучшению (TODO)
Добавить поддержку нескольких GPU

Реализовать автоматическое масштабирование (HPA) по нагрузке GPU

Интегрировать с Vault для управления секретами

Добавить сбор логов (Loki/EFK)

Написать тесты для пайплайна (conftest, kubeconform)

👨‍💻 Автор
Твоё Имя

GitHub: @username

LinkedIn: [ссылка]

Telegram: [ссылка]

📄 Лицензия
MIT

text

### Что дальше?
- Заполни секцию **Автор**.
- Если хочешь, добавь реальные скриншоты (интерфейс ComfyUI, Grafana дашборд, схему архитектуры).
- Уточни пути к файлам (docker/, k8s/, terraform/ и т.д.) в соответствии со структурой репозитория, которую ты создашь.
- В процессе реализации обновляй документацию, добавляй инструкции по возникшим сложностям.

Такая документация произведёт отличное впечатление на любого работодателя. Удачи в реализации!
