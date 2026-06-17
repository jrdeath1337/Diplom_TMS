# 🚀 Hybrid Cloud GPU Rendering System (K8s Edition)

<div align="center">

**Дипломный проект по специальности DevOps-инженер (TMS, 2026)**

[![Status](https://img.shields.io/badge/Status-Diploma-22c55e)]()
[![Tech](https://img.shields.io/badge/Tech-K8s%20%2B%20Terraform%20%2B%20Docker-007ACC)]()
[![Region](https://img.shields.io/badge/Region-Minsk%2C_BY-8B4513)]()
[![License](https://img.shields.io/badge/License-None-yellow)]()

<img src="https://github.com/trending" alt="Architecture" width="800"/>

</div>

## Цель проекта

Разработать и автоматизировать **гибридную облачную систему для генерации
изображений** с использованием локального вычислителя (CPU/GPU) и облачного
оркестратора (Managed Kubernetes). Система должна:

- **Самостоятельно разворачиваться** в Yandex Cloud одной командой (IaC).
- **Масштабироваться** и быть отказоустойчивой в части API.
- **Принимать запросы от пользователей** через веб-интерфейс и API.
- **Генерировать изображения** на локальном узле с помощью ComfyUI.
- **Хранить результаты** в облачном объектном хранилище (S3).
- **Вести историю задач** в управляемой базе данных (PostgreSQL).
- **Обеспечивать наблюдаемость** (метрики, логи, дашборды).
- **Автоматически доставлять обновления** через CI/CD-пайплайн.

Проект демонстрирует полный DevOps-цикл для AI-сервиса и применим как
основа для реальных систем генерации контента.

---

## 📋 Оглавление

- [🏗 Архитектура]
- [📊 Матрица сетевых взаимодействий]
- [🔄 Поток данных]
- [🛠 Технологический стек]
- [📁 Структура репозитория]
- [⚡ Быстрый старт]
- [🔐 CI/CD настройка]
- [✅ Команды проверки]
- [📊 Мониторинг и логирование]
- [🔄 CI/CD пайплайн]
- [Дальнейшее развитие]

---

## 🏗 Архитектура

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
```

---

## 📊 Матрица сетевых взаимодействий

| Компонент А | Компонент Б | Протокол | Метод / Операция | Примечание / Описание |
| :--- | :--- | :--- | :--- | :--- |
| **Пользователь** | API (FastAPI) | HTTP | GET, POST (JSON, HTML) | Внешний клиентский трафик |
| **API (FastAPI)** | PostgreSQL | API | INSERT, SELECT | Создание задач и чтение статусов |
| **Worker** | PostgreSQL | PostgreSQL | SELECT FOR UPDATE SKIP LOCKED, UPDATE | Конкурентный захват и обновление задач |
| **Worker** | ComfyUI | HTTP | POST, GET (JSON) | Управление генерацией нейросети |
| **Worker** | S3 | HTTPS (S3 API) | upload_file | Загрузка медиафайлов в хранилище |
| **Prometheus** | API | HTTP | GET `/metrics` | Pull-модель сбора метрик приложения |
| **Prometheus** | Node/K8s | HTTP | GET `/metrics` | Pull-модель сбора системных метрик |
| **Promtail** | Loki | gRPC / HTTP | Push logs | Отправка логов из контейнеров |
| **Grafana** | Prometheus, Loki | HTTP | API-запросы | Визуализация метрик и логов |

---

## 🌐 Сетевая инфраструктура и маршрутизация

### Входной трафик (Ingress)
* Все внешние запросы от **Пользователей** проходят через **Ingress-контроллер (NGINX)**.
* Контроллер анализирует доменное имя (Host) и направляет трафик на соответствующий сервис внутри кластера.

### Внутренние коммуникации
* Взаимодействие между внутренними подами (`API ↔ БД`, `Worker ↔ БД`, `Prometheus ↔ API`) осуществляется по **внутренним IP-адресам** K8s-кластера.
* В случае использования управляемых облачных баз данных (Managed PostgreSQL/S3) запросы могут идти через публичные/приватные адреса облачного провайдера.

---

## 🛠️ Особенности реализации бизнес-логики

1. **Очередь задач на базе БД**: 
   Использование конструкции `SELECT FOR UPDATE SKIP LOCKED` позволяет нескольким экземплярам **Worker** параллельно и безопасно разбирать задачи из таблицы PostgreSQL. Это исключает блокировки (deadlocks) и обеспечивает горизонтальное масштабирование воркеров.
2. **Асинхронный пайплайн**: 
   **API** быстро принимает запрос от пользователя, фиксирует его в БД и освобождает поток. **Worker** подхватывает задачу, передает тяжелую генерацию в **ComfyUI**, сохраняет результат в **S3** и обновляет статус в **PostgreSQL**.


---

## 🔄 Поток данных

1. **Пользователь** отправляет `prompt` через веб-интерфейс `/ui` или API (`POST /generate`).
2. **API** создаёт запись в таблице `tasks` PostgreSQL со статусом `pending`.
3. **Локальный worker** опрашивает БД (атомарно захватывает одну задачу), передаёт `prompt` в ComfyUI, ожидает генерации.
4. **Готовое изображение** загружается в Yandex Object Storage (S3).
5. **Worker** обновляет статус задачи в БД (`completed` → ссылка на файл).
6. **Пользователь** проверяет статус (`GET /status/{id}`) и получает `result_url`.

> Все запросы метрикуются (Prometheus) и логируются (Loki). Дашборды доступны в Grafana.

---

## 🛠 Технологический стек

| Категория | Инструменты | Назначение |
|-----------|-------------|------------|
| **IaC** | Terraform, Yandex Cloud | Создание облачной инфраструктуры |
| **Оркестрация** | Managed Kubernetes, Helm | Запуск и масштабирование API |
| **Контейнеризация** | Docker, Docker Compose | Упаковка API и воркера |
| **API** | FastAPI (Python 3.10) | Приём промптов, работа с БД |
| **База данных** | Managed PostgreSQL | Хранение задач и статусов |
| **Хранилище** | Yandex Object Storage (S3) | Хранение сгенерированных изображений |
| **Мониторинг** | Prometheus, Grafana | Метрики API, визуализация |
| **Логирование** | Loki, Promtail, Grafana | Сбор и просмотр логов |
| **CI/CD** | GitHub Actions | Автотесты, сборка, деплой |
| **Безопасность** | Kubernetes Secrets | Чувствительные переменные окружения |

---

## 📁 Структура репозитория

```bash
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
├── monitoring-deploy.sh               # Установка только K8s-компонентов и мониторинга
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
```

> **Основные файлы:**
> - `full-deploy.sh` — запускает всё: Terraform, сборку, деплой API и воркера.
> - `monitoring-deploy.sh` — устанавливает только K8s-компоненты и мониторинг.
> - `app/worker_core.py` — основной цикл обработки задач.
> - `Docker/api/api_server.py` — FastAPI-приложение с эндпоинтами и веб-интерфейсом.

---

## ⚡ Быстрый старт (полное развёртывание)

> ⚠️ **Важно:** перед первым запуском заполните `terraform/terraform.tfvars` своими данными (облачные ID, пароли, токены). Файл содержит секреты и не должен коммититься в Git.

```bash
cd ~/Diplom_TMS
./full-deploy.sh
```

После завершения скрипт выведет:

| Сервис | URL | Логин/Пароль |
|--------|-----|--------------|
| **API** | `http://api.<INGRESS_IP>.nip.io/health` | — |
| **Grafana** | `http://grafana.<INGRESS_IP>.nip.io` | `admin` / `admin123` |
| **Веб-интерфейс** | `http://api.<INGRESS_IP>.nip.io/ui` | — |

---

## 🔐 Настройка CI/CD (секреты GitHub Actions)

Для автоматического деплоя при пуше в `main` добавьте секреты в **Settings → Secrets → Actions**:

| Секрет | Как получить |
|--------|--------------|
| `YC_OAUTH_TOKEN` | OAuth-токен Яндекса: [получить здесь](https://cloud.yandex.ru/ru/docs/iam/concepts/authorization/oauth-token) |
| `YC_CLOUD_ID` | `terraform.tfvars` или `yc config list` |
| `YC_FOLDER_ID` | `terraform.tfvars` или `yc config list` |
| `YC_REGISTRY_ID` | `yc container registry list` — ID Container Registry |
| `YC_CLUSTER_ID` | `terraform -chdir=terraform output -raw k8s_cluster_id` |
| `INGRESS_IP` | `kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |

> После `terraform destroy && terraform apply` обновите только `YC_CLUSTER_ID` и `INGRESS_IP`.

---

## ✅ Команды проверки системы

### Поды и Ingress
```bash
kubectl get pods -A
kubectl get ingress -A
```

### Таблица задач (PostgreSQL)
```bash
kubectl exec -it deployment/hybrid-api-api -- python3 -c "
import psycopg2, os
conn = psycopg2.connect(os.getenv('DB_DSN'))
cur = conn.cursor()
cur.execute('SELECT id, status, result_url, error_msg, created_at FROM tasks ORDER BY id')
cols = ['ID','STATUS','RESULT_URL','ERROR_MSG','CREATED_AT']
print(' | '.join(cols))
print('-' * 100)
for row in cur.fetchall():
    print(f'{row:<4} | {row:<10} | {row or \"\":<40} | {row or \"\":<20} | {row}')
conn.close()
"
```

**Пример вывода:**

| ID | STATUS    | RESULT_URL                      | ERROR_MSG  | CREATED_AT          |
| -- | --------- | ------------------------------- | ---------- | ------------------- |
| 1  | completed | https://...results/1_123456.png |            | 2026-06-15 10:15:00 |
| 2  | failed    |                                 | Timeout... | 2026-06-15 10:20:00 |

text

### Логи
```bash
# API
kubectl logs deployment/hybrid-api-api --tail 20

# Worker
docker compose logs worker --tail 20
```

### Интеграционный тест
```bash
INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress.ip}')

# Healthcheck
curl -s http://api.$INGRESS_IP.nip.io/health

# Создать задачу
curl -X POST http://api.$INGRESS_IP.nip.io/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a cat","steps":5}'

# Проверить статус
curl -s http://api.$INGRESS_IP.nip.io/status/1
```

---

## 📊 Мониторинг и логирование

### Единый дашборд «Hybrid GPU – Full Monitoring»

| Панель | Описание | Единицы |
|--------|----------|---------|
| **Requests per Second** | Частота запросов по handler'ам | reqps |
| **Error Rate (5xx)** | Процент ошибок сервера (500–599) | % |
| **Average Response Time** | Среднее время ответа по handler'ам | секунды |
| **Total Requests** | Общее количество запросов | абсолютное число |
| **Response Status Codes** | Распределение по HTTP-статусам | число |
| **CPU Usage per Node** | Загрузка CPU на каждой ноде | % (0–100) |
| **Memory Usage per Node** | Использование памяти на нодах | % (0–100) |
| **Running Pods** | Количество подов в статусе Running | абсолютное число |
| **API Logs** | Логи FastAPI (поиск ошибок) | текст |

### Как это работает
1. **Prometheus** опрашивает `/metrics` FastAPI и другие цели каждые 30 сек.
2. **Promtail** собирает логи со всех подов → отправляет в **Loki**.
3. **Grafana** визуализирует метрики и логи в едином интерфейсе.

### Дополнительные дашборды в Grafana
- `Kubernetes / Compute Resources / Cluster` — утилизация ресурсов кластера
- `Kubernetes / Compute Resources / Pod` — CPU и память каждым подом
- `Node Exporter / Nodes` — детальные метрики нод (диски, сеть)

---

## 🔄 CI/CD пайплайн

При пуше в `main` (и изменении `Docker/api/**`, `helm/**`, `tests/**`) запускается:

1. **Lint & Test** — `flake8`, `black`, `isort` + `pytest`
2. **Build & Deploy** — сборка Docker-образа → пуш в Yandex Container Registry → обновление Helm-релиза

> Workflow генерирует `kubeconfig` на лету через `yc` — ручное обновление не требуется.

---

## Дальнейшее развитие

-  **GitOps (ArgoCD)** — автоматическая синхронизация кластера с Git
-  **GPU-ускорение** — переход на ROCm-образ (RX 9070 XT)
-  **Шифрение секретов** — External Secrets Operator
-  **Автомасштабирование** — HorizontalPodAutoscaler для API + несколько воркеров

---

<div align="center">

**Проект выполнен в рамках дипломной работы по специальности «DevOps-инженер» (TMS, 2026)**  
📍 Minsk, BY

</div>
