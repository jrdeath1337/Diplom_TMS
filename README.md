# Hybrid Cloud GPU Rendering System (K8s Edition)

Дипломный проект по специальности **DevOps-инженер** (TMS, 2026).

**Гибридная облачная система генерации изображений** с использованием
Managed Kubernetes (Yandex Cloud) и локального вычислителя на CPU/GPU.
Проект автоматизирует полный цикл: инфраструктура как код (Terraform),
контейнеризация (Docker), оркестрация (Kubernetes), мониторинг (Prometheus +
Grafana), логирование (Loki), CI/CD (GitHub Actions).

---

## Оглавление

- [Архитектура](#архитектура)
- [Поток данных](#поток-данных)
- [Технологический стек](#технологический-стек)
- [Структура репозитория](#структура-репозитория)
- [Быстрый старт (полное развёртывание)](#быстрый-старт-полное-развёртывание)
- [Настройка CI/CD (секреты GitHub Actions)](#настройка-cicd-секреты-github-actions)
- [Команды проверки системы](#команды-проверки-системы)
- [Мониторинг и логирование](#мониторинг-и-логирование)
- [CI/CD пайплайн](#cicd-пайплайн)
- [Дальнейшее развитие](#дальнейшее-развитие)

---

```text
                                  ИНТЕРНЕТ (Пользователи)
                                             │
                                             ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ CLOUD: Yandex Managed Kubernetes                                                       │
│                                                                                        │
│   ┌───────────────────────────────┐                  ┌───────────────────────────────┐ │
│   │ Ingress Controller (NGINX)    │                  │ Monitoring Stack              │ │
│   │ URL: ://yourdomain.com        │                  │ (Prometheus + Grafana + Loki) │ │
│   └───────────────┬───────────────┘                  └───────────────────────────────┘ │
│                   │                                                                    │
│                   ▼                                                                    │
│   ┌───────────────────────────────┐                                                    │
│   │ API Service (FastAPI)         │                                                    │
│   │ [ Реплика 1 ]   [ Реплика 2 ] │                                                    │
│   └───────────────┬───────────────┘                                                    │
│                   │                                                                    │
│                   ▼                                                                    │
│   ┌───────────────────────────────┐                                                    │
│   │ Managed PostgreSQL            │◀──────────────────────────────────┐                │
│   │ (Хранение данных и задач)     │                                   │                │
│   └───────────────┬───────────────┘                                   │                │
│                   │                                                   │                │
│                   ▼                                                   │                │
│   ┌───────────────────────────────┐                                   │                │
│   │ Object Storage (S3)           │◀──────────────────┐               │                │
│   │ (Хранилище изображений)       │                   │               │                │
│   └───────────────────────────────┘                   │               │                │
└───────────────────────────────────────────────────────┼───────────────┼────────────────┘
                                                        │               │
                                              [S3 Изображения]     [БД Задачи]
                                                        │               │
┌───────────────────────────────────────────────────────┼───────────────┼────────────────┐
│ EDGE: Локальный узел (Docker Compose)                 │               │                │
│                                                       │               │                │
│   ┌───────────────────────────────────────────────────┴───────────────┴────────────┐   │
│   │ Worker (Python + ComfyUI + ROCm)                                               │   │
│   │                                                                                │   │
│   │  1. Забирает новые задачи из PostgreSQL через "SELECT FOR UPDATE"              │   │
│   │  2. Генерирует изображения на GPU AMD (через стек ROCm)                        │   │
│   │  3. Загружает готовые файлы напрямую в облачный S3-бакет                       │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────┘
Поток данных
Пользователь отправляет prompt через веб-интерфейс /ui или напрямую в
API (POST /generate).

API создаёт запись в таблице tasks PostgreSQL со статусом pending.

Локальный worker опрашивает БД (атомарно захватывает одну задачу),
передаёт prompt в ComfyUI, ожидает генерации изображения.

Готовое изображение загружается в Yandex Object Storage (S3).

Worker обновляет статус задачи в БД (completed → ссылка на файл).

Пользователь может повторно запросить статус (GET /status/{id}) и
получить result_url.

Все запросы к API метрикуются (Prometheus) и логируются (Loki).
Дашборды доступны в Grafana.

Технологический стек
Категория	Инструменты	Назначение
IaC	Terraform, Yandex Cloud	Создание облачной инфраструктуры
Оркестрация	Managed Kubernetes, Helm	Запуск и масштабирование API
Контейнеризация	Docker, Docker Compose	Упаковка API и воркера
API	FastAPI (Python 3.10)	Приём промптов, работа с БД
База данных	Managed PostgreSQL	Хранение задач и статусов
Хранилище	Yandex Object Storage (S3)	Хранение сгенерированных изображений
Мониторинг	Prometheus, Grafana	Метрики API, визуализация
Логирование	Loki, Promtail, Grafana	Сбор и просмотр логов
CI/CD	GitHub Actions	Автотесты, сборка, деплой
Безопасность	Kubernetes Secrets	Чувствительные переменные окружения
Структура репозитория
text
.
├── app/
│   └── worker_core.py                 # Логика воркера (БД → ComfyUI → S3)
├── Docker/
│   ├── api/
│   │   ├── api_server.py              # FastAPI-приложение
│   │   ├── Dockerfile                 # Сборка образа API
│   │   └── requirements.txt           # Python-зависимости API
│   ├── worker/
│   │   └── Dockerfile                 # Сборка образа воркера (ComfyUI, ROCm/CPU)
│   └── entrypoint.sh                  # Точка входа контейнера воркера
├── docker-compose.yml                 # Локальный запуск worker'а
├── full-deploy.sh                     # Полный деплой с нуля (Terraform + все компоненты)
├── monitoring-deploy.sh               # Установка только Kubernetes-компонентов и мониторинга
├── helm/
│   └── hybrid-api/
│       ├── Chart.yaml                 # Метаданные Helm-чарта
│       ├── values.tftpl               # Шаблон values.yaml (заполняется Terraform)
│       └── templates/
│           ├── deployment.yaml        # Deployment API
│           ├── service.yaml           # Service
│           ├── ingress.yaml           # Ingress
│           └── servicemonitor.yaml    # ServiceMonitor для Prometheus
├── monitoring-dashboards/
│   └── fastapi-metrics.json           # Дашборд Grafana (импортируется автоматически)
├── terraform/                         # Инфраструктура как код
│   ├── provider.tf                    # Провайдеры (Yandex, Kubernetes, Helm, ...)
│   ├── variables.tf                   # Объявление входных переменных
│   ├── network.tf                     # VPC, подсеть, security group
│   ├── postgresql.tf                  # Managed PostgreSQL, БД, пользователь
│   ├── storage.tf                     # Object Storage (S3)
│   ├── iam.tf                         # Сервисный аккаунт, ключи доступа
│   ├── container-registry.tf          # Container Registry
│   ├── k8s.tf                         # Managed Kubernetes, группа узлов
│   ├── env.tf                         # Генерация cpu-worker.env и values.yaml
│   ├── outputs.tf                     # Выходные переменные
│   └── k8s-secrets.tf                 # Kubernetes Secret (опционально)
├── tests/
│   ├── test_api.py                    # Тесты FastAPI
│   └── test_worker.py                 # Тесты воркера
├── .github/workflows/
│   └── deploy.yml                     # CI/CD пайплайн (GitHub Actions)
└── README.md                          # ← этот документ
Примечание: Файлы, перечисленные в .gitignore (*.tfstate, *.tfvars,
*.json, *.env, сгенерированный values.yaml), не хранятся в репозитории
и поэтому не показаны в дереве.

Основные файлы:

full-deploy.sh – запускает вообще всё: Terraform, сборку образа,
установку Ingress, мониторинга, API и воркера. После выполнения система
полностью готова.

monitoring-deploy.sh – устанавливает только Kubernetes-компоненты (Ingress,
Prometheus, Grafana, Loki, API). Используется при повторных деплоях или после
terraform apply.

app/worker_core.py – основной цикл обработки задач.

Docker/api/api_server.py – FastAPI-приложение с эндпоинтами и
веб-интерфейсом.

helm/hybrid-api/ – Helm-чарт для развёртывания API в Kubernetes.

terraform/ – вся облачная инфраструктура как код.

monitoring-dashboards/fastapi-metrics.json – JSON-дашборд для Grafana
(автоматически импортируется при деплое).

Быстрый старт (полное развёртывание)
Важно: перед первым запуском заполните terraform/terraform.tfvars
своими данными (облачные ID, пароли, токены). Файл содержит секреты и не
должен коммититься в Git.

bash
cd ~/Diplom_TMS
./full-deploy.sh
После завершения скрипт выведет список секретов для GitHub Actions и URL-адреса

API: http://api.<INGRESS_IP>.nip.io/health

Grafana: http://grafana.<INGRESS_IP>.nip.io (admin / admin123)

Веб-интерфейс: http://api.<INGRESS_IP>.nip.io/ui

Настройка CI/CD (секреты GitHub Actions)
Для работы автоматического деплоя при пуше в main необходимо добавить
следующие секреты в Settings → Secrets → Actions репозитория:

Секрет	Как получить
YC_OAUTH_TOKEN	OAuth‑токен Яндекса. Можно взять здесь
YC_CLOUD_ID	ID облака из terraform.tfvars или yc config list
YC_FOLDER_ID	ID каталога из terraform.tfvars или yc config list
YC_REGISTRY_ID	yc container registry list – ID Container Registry
YC_CLUSTER_ID	terraform -chdir=terraform output -raw k8s_cluster_id
INGRESS_IP	kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
После пересоздания инфраструктуры (terraform destroy && terraform apply)
достаточно обновить YC_CLUSTER_ID и INGRESS_IP. Остальные секреты не
меняются.

Команды проверки системы
Проверка подов и Ingress

bash
kubectl get pods -A
kubectl get ingress -A
Проверка таблицы задач (PostgreSQL)

bash
kubectl exec -it deployment/hybrid-api-api -- python3 -c "
import psycopg2, os
conn = psycopg2.connect(os.getenv('DB_DSN'))
cur = conn.cursor()
cur.execute('SELECT id, status, result_url, error_msg, created_at FROM tasks ORDER BY id')
cols = ['ID','STATUS','RESULT_URL','ERROR_MSG','CREATED_AT']
print(' | '.join(cols))
print('-' * 100)
for row in cur.fetchall():
    print(f'{row[0]:<4} | {row[1]:<10} | {row[2] or \"\":<40} | {row[3] or \"\":<20} | {row[4]}')
conn.close()
"
Пример вывода:

text
ID | STATUS     | RESULT_URL                               | ERROR_MSG            | CREATED_AT
--------------------------------------------------------------------------------------------------------
1  | completed  | https://...results/1_123456.png         |                      | 2026-06-15 10:15:00
2  | failed     |                                          | Timeout...           | 2026-06-15 10:20:00
Логи API

bash
kubectl logs deployment/hybrid-api-api --tail 20
Логи воркера

bash
docker compose logs worker --tail 20
Полный интеграционный тест

bash
INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# healthcheck
curl -s http://api.$INGRESS_IP.nip.io/health
# создать задачу
curl -X POST http://api.$INGRESS_IP.nip.io/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a cat","steps":5}'
# проверить статус (подставить task_id)
curl -s http://api.$INGRESS_IP.nip.io/status/1
Мониторинг и логирование
Единый дашборд мониторинга
После развёртывания в Grafana автоматически импортируется дашборд
«Hybrid GPU – Full Monitoring», объединяющий все ключевые метрики и логи
системы.

Что отображается на дашборде

Панель	Описание	Единицы
Requests per Second	Частота запросов по handler'ам и методам	reqps
Error Rate (5xx)	Процент ошибок сервера (коды 500–599)	%
Average Response Time	Среднее время ответа для каждого handler'а	секунды
Total Requests	Общее количество запросов по handler'ам	абсолютное число
Response Status Codes	Распределение запросов по HTTP-статусам (200, 404, 422, 500 и др.)	число
CPU Usage per Node	Загрузка процессора на каждой ноде кластера	% (0–100)
Memory Usage per Node	Использование оперативной памяти на нодах	% (0–100)
Running Pods	Количество подов в статусе Running	абсолютное число
API Logs	Логи FastAPI (поиск ошибок, просмотр запросов)	текст
Источники данных

Метрики приложения (FastAPI) собираются Prometheus через библиотеку
prometheus_fastapi_instrumentator (эндпоинт /metrics).

Инфраструктурные метрики (CPU, память, поды) собираются node-exporter и
kube-state-metrics, которые автоматически устанавливаются вместе с
kube-prometheus-stack.

Логи собираются Promtail, хранятся в Loki и отображаются в Grafana.

Дополнительные дашборды
В Grafana также доступны встроенные дашборды Kubernetes (устанавливаются
автоматически):

Kubernetes / Compute Resources / Cluster – общая утилизация ресурсов
кластера.

Kubernetes / Compute Resources / Pod – потребление CPU и памяти каждым
подом.

Node Exporter / Nodes – детальные метрики нод (диски, сеть, нагрузка).

Эти дашборды можно найти в разделе Dashboards → Manage.

Как это работает

Prometheus опрашивает /metrics FastAPI и другие цели (node-exporter,
kube-state-metrics) каждые 30 секунд.

Promtail собирает логи со всех подов и отправляет их в Loki.

Grafana визуализирует метрики и логи, предоставляя единый интерфейс для
наблюдения за системой.

CI/CD пайплайн
При каждом пуше в ветку main (и изменении файлов в Docker/api/**,
helm/**, tests/**) запускается GitHub Actions workflow:

Lint & Test – проверка кода линтерами (flake8, black, isort) и
запуск pytest.

Build & Deploy – сборка Docker-образа с тегом коммита, пуш в Yandex
Container Registry, обновление Helm-релиза в Kubernetes.

Workflow не требует ручного обновления kubeconfig – он генерируется на лету с
помощью yc.

Дальнейшее развитие
GitOps (ArgoCD) – автоматическая синхронизация кластера с Git.

GPU-ускорение – переход на ROCm-образ при стабильной поддержке RX 9070 XT.

Шифрование секретов – интеграция с External Secrets Operator.

Автомасштабирование – HorizontalPodAutoscaler для API и несколько
воркеров.

*Проект выполнен в рамках дипломной работы по специальности «DevOps-инженер»
(TMS, 2026).*
