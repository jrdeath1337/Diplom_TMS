resource "local_sensitive_file" "worker_env" {
  filename        = "${path.module}/cpu-worker.env"
  content         = <<-EOT
DB_DSN=postgresql://${var.postgres_user}:${var.postgres_password}@${yandex_mdb_postgresql_cluster.pg.host[0].fqdn}:6432/${var.postgres_dbname}?sslmode=require
S3_BUCKET=${yandex_storage_bucket.images.bucket}
AWS_ACCESS_KEY_ID=${yandex_iam_service_account_static_access_key.worker_sa_key.access_key}
AWS_SECRET_ACCESS_KEY=${yandex_iam_service_account_static_access_key.worker_sa_key.secret_key}
S3_ENDPOINT=https://storage.yandexcloud.net
POLL_INTERVAL=5
GENERATION_TIMEOUT=300
EOT
  file_permission = "0600"   # только владелец может читать
}
