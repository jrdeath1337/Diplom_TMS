# Создание бакета
resource "yandex_storage_bucket" "images" {
  bucket    = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-images-${substr(uuid(), 0, 8)}"
  folder_id = "b1g8kqntl9atl3khrhkg"
  # Убираем устаревший аргумент acl
  # depends_on больше не нужен, так как для создания бакета права не требуются
  depends_on = [yandex_resourcemanager_folder_iam_member.storage_editor]
  force_destroy = true

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

# Выдача публичного доступа на чтение с помощью IAM
resource "yandex_storage_bucket_iam_binding" "public_read" {
  bucket = yandex_storage_bucket.images.bucket
  role   = "storage.viewer"
  members = [
    "system:allUsers", # Эта специальная сущность предоставляет доступ всем пользователям интернета
  ]
}
