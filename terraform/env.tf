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
  file_permission = "0600" # только владелец может читать
}

resource "local_file" "helm_values" {
  filename = "${path.root}/../helm/hybrid-api/values.yaml"
  content = templatefile("${path.root}/../helm/hybrid-api/values.tftpl", {
    registry_id  = yandex_container_registry.default.id
    ingress_host = "api.${yandex_kubernetes_cluster.main.master[0].external_v4_endpoint}.nip.io"
    db_dsn       = "postgresql://${var.postgres_user}:${var.postgres_password}@${yandex_mdb_postgresql_cluster.pg.host[0].fqdn}:6432/${var.postgres_dbname}?sslmode=require"
    s3_bucket    = yandex_storage_bucket.images.bucket
    access_key   = yandex_iam_service_account_static_access_key.worker_sa_key.access_key
    secret_key   = yandex_iam_service_account_static_access_key.worker_sa_key.secret_key
    s3_endpoint  = "https://storage.yandexcloud.net"
  })
  file_permission = "0644"
}
