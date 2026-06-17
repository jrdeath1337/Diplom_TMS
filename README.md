# Hybrid Cloud GPU Rendering System (K8s Edition)

Дипломный проект: автоматизация гибридной облачной инфраструктуры для генерации изображений с использованием Managed Kubernetes (Yandex Cloud) и локального GPU AMD (ROCm).

**Статус:** учебный прототип. Отдельные аспекты безопасности и отказоустойчивости упрощены для демонстрации концепции.

## Архитектура

Система состоит из двух основных контуров:

1. **Облачный контур (Yandex Cloud)**
   - **API-сервис** (FastAPI) в Managed Kubernetes принимает запросы пользователей.
   - **База данных** Managed PostgreSQL хранит очередь задач и статусы.
   - **Хранилище** Yandex Object Storage (S3) для готовых изображений.
   - **Мониторинг** Prometheus + Grafana (сбор метрик API).
   - **Логирование** Loki + Grafana
   - **Ingress-контроллер** NGINX для доступа к API и Grafana.

2. **Локальный контур (On-premise)**
   - **Worker** на Python + **ComfyUI** (в Docker-контейнере) на машине с GPU AMD ROCm (RX 9070 XT).
   - Worker забирает задачи из облачной БД, отправляет на генерацию в ComfyUI, результат загружает в S3, обновляет статус.
   - Для связи используется публичный IP (в перспективе WireGuard-туннель).

![Архитектура](docs/architecture.png) *(если есть схема)*

Поток данных:
1. `POST /generate` → API создаёт задачу в PostgreSQL (статус `pending`).
2. Worker опрашивает БД → переводит задачу в `processing`.
3. Worker отправляет workflow в ComfyUI → ожидает генерации → получает файл.
4. Файл загружается в S3, статус обновляется до `completed` (или `failed`), ссылка сохраняется.
5. Клиент через `GET /status/{id}` получает результат.

## Технологический стек

| Уровень          | Технологии                                         |
| ---------------- | -------------------------------------------------- |
| Инфраструктура   | Terraform (Yandex Cloud)                           |
| Оркестрация      | Yandex Managed Kubernetes, Helm                    |
| Контейнеризация  | Docker, Docker Compose                             |
| API              | FastAPI (Python)                                   |
| База данных      | Yandex Managed PostgreSQL                          |
| Хранилище        | Yandex Object Storage (S3)                         |
| Мониторинг       | Prometheus Operator, Grafana, Loki                 |
| CI/CD            | GitHub Actions (только для API – см. ниже)         |

## Структура репозитория
.
├── app/ # Исходный код воркера
│ ├── worker_core.py
│ └── README.me
├── docker/ # Сборка контейнеров
│ ├── api/ # API-сервер
│ │ ├── Dockerfile
│ │ ├── api_server.py
│ │ └── requirements.txt
│ ├── worker/ # Worker (ComfyUI + воркер)
│ │ └── Dockerfile
│ └── entrypoint.sh # Точка входа для контейнера worker
├── helm/
│ └── hybrid-api/ # Helm-чарт для API
│ ├── Chart.yaml
│ ├── templates/
│ │ ├── deployment.yaml
│ │ ├── ingress.yaml
│ │ ├── servicemonitor.yaml
│ │ └── service.yaml
│ └── values.tftpl # Шаблон values (заполняется Terraform)
├── terraform/ # Инфраструктура Yandex Cloud
│ ├── *.tf # Основные файлы Terraform
│ ├── outputs.tf
│ ├── variables.tf
│ ├── terraform.tfvars # (не в репозитории – хранит секреты)
│ └── .terraform.lock.hcl
├── monitoring-dashboards/ # Дашборд Grafana
│ └── fastapi-metrics.json
├── docker-compose.yml # Локальный запуск (для разработки/воркера)
├── deploy.sh # Скрипт деплоя API + мониторинга
├── full-deploy.sh # Полный деплой с нуля (Terraform + приложения)
└── README.md

text

**Примечание:** Файлы, содержащие секреты (`terraform.tfvars`, `s3-key.json`, `cpu-worker.env`, `outputs.json`, `terraform.tfstate*`) и их резервные копии **исключены** из репозитория (см. `.gitignore`).

## Быстрый старт (полное развёртывание)

Все команды выполняются на машине с доступом к Yandex Cloud и настроенным `yc` CLI.

1. **Клонируйте репозиторий**:
   ```bash
   git clone <url>
   cd Diplom_TMS
Настройте переменные Terraform:
Создайте в папке terraform/ файл terraform.tfvars:

hcl
yc_cloud_id        = "<ваш cloud-id>"
yc_folder_id       = "<ваш folder-id>"
yc_token           = "<ваш OAuth-токен>"
postgres_password  = "<надёжный пароль>"
Запустите полный деплой:

bash
./full-deploy.sh
Скрипт последовательно выполнит:

terraform apply – создание облачной инфраструктуры.

Подключение к кластеру Kubernetes.

Сборку и публикацию образа API в Container Registry.

Установку NGINX Ingress, Prometheus, Grafana, Loki.

Деплой API через Helm.

Запуск локального worker (если настроен Docker Compose).

После завершения в консоли отобразятся URL:

API: http://api.<внешний-IP>.nip.io/health

Grafana: http://grafana.<внешний-IP>.nip.io (логин admin, пароль admin123)

Проверка:

Откройте API: curl http://api.<IP>.nip.io/health

Откройте Grafana, перейдите на дашборд «Hybrid GPU API Metrics».

Для проверки worker’а отправьте запрос на генерацию:

bash
curl -X POST http://api.<IP>.nip.io/generate \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"a cat, high quality", "steps":3}'
Затем проверьте статус по полученному task_id.

Ручное развёртывание (по шагам)
Если вы предпочитаете контролировать процесс:

Terraform:

bash
cd terraform
terraform init
terraform apply
cd ..
Подключение к кластеру:

bash
yc managed-kubernetes cluster get-credentials <cluster-id> --external --force
Сборка и пуш образа API:

bash
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')
docker login --username iam --password-stdin cr.yandex <<< $(yc iam create-token)
docker build -t cr.yandex/$REGISTRY_ID/hybrid-api:v0.1 ./docker/api
docker push cr.yandex/$REGISTRY_ID/hybrid-api:v0.1
Деплой:

bash
./deploy.sh
Worker (на локальной машине с GPU):

Убедитесь, что файл cpu-worker.env (сгенерированный Terraform) лежит в корне проекта.

Выполните docker compose up -d worker.

Мониторинг
Grafana доступна по адресу из вывода deploy.sh.

Встроенный дашборд «Hybrid GPU API Metrics» показывает:

RPS (запросы в секунду),

Доля ошибок 5xx,

Среднее время ответа,

Общее количество запросов.

Метрики собираются Prometheus Operator через ServiceMonitor (настроен автоматически).

Loki собирает логи всех подов (доступен в Grafana Explore).

CI/CD (Continuous Integration / Continuous Deployment)
В проекте реализован автоматический пайплайн для API-сервиса на GitHub Actions.

Что автоматизировано: при каждом пуше в ветку main (изменения в docker/api/** или helm/**) запускается workflow, который:

Собирает Docker-образ API.

Публикует его в Yandex Container Registry.

Обновляет Helm-релиз в кластере Kubernetes.

Настройка:

Необходимо добавить в секреты репозитория (Settings → Secrets → Actions):

YC_OAUTH_TOKEN – OAuth-токен Yandex Cloud.

REGISTRY_ID – идентификатор контейнерного реестра.

KUBECONFIG – содержимое kubeconfig в формате base64.

INGRESS_IP – внешний IP Ingress-контроллера.

Workflow-файл: .github/workflows/deploy-api.yml.

Локальный worker обновляется вручную (в рамках дипломной работы это допустимо).

Примечания к учебному прототипу
Безопасность: для простоты PostgreSQL разрешает подключения со всех IP (0.0.0.0/0), а API не требует аутентификации. В реальной системе следует ограничить firewall и добавить API-ключи.

Отказоустойчивость: используется один экземпляр PostgreSQL (без реплик) и один локальный worker. Для продакшена необходимо реплицирование БД и кластеризация worker’ов.

GPU: по умолчанию worker работает в CPU-режиме (флаг --cpu в ComfyUI). Для активации GPU необходимо собрать образ с поддержкой ROCm и удалить этот флаг. Это ограничение вызвано отсутствием драйверов на тестовой машине.

Заключение
Проект демонстрирует полный цикл DevOps для гибридной облачной системы: инфраструктура как код, контейнеризация, оркестрация, мониторинг и непрерывная доставка. Он готов к расширению и может служить основой для реальной системы генерации контента.

По всем вопросам обращайтесь к автору дипломной работы.
