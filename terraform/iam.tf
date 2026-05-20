# Сервисный аккаунт для доступа воркера к S3 и (опционально) к БД
resource "yandex_iam_service_account" "worker_sa" {
  name        = "${var.project_name}-worker-sa"
  description = "Service account used by local worker to access S3 and PostgreSQL"
}

# Статические ключи доступа для S3 (используются в worker_core.py)
resource "yandex_iam_service_account_static_access_key" "worker_sa_key" {
  service_account_id = yandex_iam_service_account.worker_sa.id
  description        = "Static access key for Yandex Object Storage"
}

# Даём права на S3 (storage.editor)
resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.worker_sa.id}"
}

output "worker_sa_access_key" {
  value     = yandex_iam_service_account_static_access_key.worker_sa_key.access_key
  sensitive = true
}

output "worker_sa_secret_key" {
  value     = yandex_iam_service_account_static_access_key.worker_sa_key.secret_key
  sensitive = true
}
# (Опционально) Даём права на чтение Managed PostgreSQL (не обязательно, т.к. аутентификация по паролю)
# Но если хотите использовать IAM-доступ к БД, раскомментируйте:
# resource "yandex_resourcemanager_folder_iam_member" "postgres_viewer" {
#   folder_id = var.folder_id
#   role      = "mdb.viewer"
#   member    = "serviceAccount:${yandex_iam_service_account.worker_sa.id}"
# }
