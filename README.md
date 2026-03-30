#  Hybrid Cloud GPU Rendering System (K8s Edition)

**Тема дипломного проекта:** Проектирование и автоматизация гибридной облачной инфраструктуры для масштабируемой генерации контента с использованием Managed Kubernetes и локальных мощностей AMD GPU (ROCm).

---

## 📝 Описание концепции
Проект реализует гибридную модель: оркестрация, API и хранение данных находятся в **Yandex Cloud (Managed K8s)**, а тяжелые вычисления вынесены на **On-premise** узел с **AMD Radeon RX 9070 XT**. Это позволяет обходить ограничения облачных триалов на GPU и кратно снижать стоимость владения системой.

**Ключевая особенность:** Использование K8s для управления жизненным циклом запросов и автоматизация доставки кода (CI/CD) на гетерогенное железо (Cloud CPU + Local GPU).

---

## 🛠 Технологический стек (Full Stack)


| Уровень | Технология | Роль в проекте |
| :--- | :--- | :--- |
| 🏗 **Infrastructure** | **Terraform** | IaC для создания VPC, K8s кластера, S3 и PostgreSQL |
| ☁️ **Orchestration** | **Yandex Managed K8s** | Оркестрация API-сервисов, Ingress-контроллеров и очередей |
| ⚡ **Computing** | **AMD RX 9070 XT** | Вычислительный узел (архитектура gfx1201) на базе Nobara Linux |
| 📦 **Packaging** | **Helm** | Управление релизами приложений внутри Kubernetes |
| 🐳 **Runtime** | **Docker + ROCm** | Изоляция окружения нейросети и проброс GPU |
| 💾 **Database** | **PostgreSQL** | Хранение метаданных пользователей и истории генераций |
| 🪣 **Storage** | **Yandex Object Storage** | S3-бакет для постоянного хранения готовых изображений |
| 🔗 **Networking** | **WireGuard + K8s Services** | Защищенный туннель и интеграция внешнего воркера в кластер |
| 🔄 **CI/CD** | **GitHub Actions** | Автоматизация сборки образов и деплоя манифестов |

---

## 🏗 Архитектура и поток данных (Workflow)

1. **Entry Point:** Запрос пользователя поступает на **Nginx Ingress** в кластере Kubernetes.
2. **API Layer:** Микросервис в K8s регистрирует задачу в **PostgreSQL** и передает запрос в очередь.
3. **Hybrid Link:** Через **WireGuard** туннель запрос уходит на локальный воркер.
4. **GPU Processing:** Контейнер на базе **ROCm** выполняет инференс на **RX 9070 XT** через ComfyUI API.
5. **Artifact Storage:** Готовый результат загружается напрямую в **Yandex S3**.
6. **Finalize:** Воркер обновляет статус в БД. API отдает пользователю ссылку на результат.

---

## 📂 Структура репозитория

```bash
.
├── terraform/                # Infrastructure as Code
│   ├── main.tf               # Провайдеры (Yandex)
│   ├── k8s.tf                # Managed Kubernetes Cluster & Node groups
│   ├── db.tf                 # Managed PostgreSQL configuration
│   └── storage.tf            # S3 Bucket & IAM policy
├── helm/                     # Kubernetes manifests
│   ├── api-service/          # Чарты для облачного API
│   └── ingress/              # Настройки Nginx Ingress и TLS
├── docker/                   # Контейнеризация
│   ├── worker-rocm/          # Образ ComfyUI + ROCm (для Nobara)
│   └── api-server/           # Образ легковесного API (для K8s)
├── app/                      # Исходный код (Python)
│   ├── db_client.py          # Логика работы с PostgreSQL
│   └── worker_core.py        # Обработка очередей и запуск ComfyUI
├── scripts/                  # Автоматизация
│   └── setup_wireguard.sh    # Конфигурация туннеля
└── .github/workflows/        # CI/CD пайплайны
