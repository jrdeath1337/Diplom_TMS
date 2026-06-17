resource "kubernetes_secret_v1" "api_secrets" {
  metadata {
    name      = "hybrid-api-secrets"
    namespace = "default" # или то же пространство, куда деплоится API
  }

  data = {
    DB_DSN                = "postgresql://${var.postgres_user}:${var.postgres_password}@${yandex_mdb_postgresql_cluster.pg.host[0].fqdn}:6432/${var.postgres_dbname}?sslmode=require"
    S3_BUCKET             = yandex_storage_bucket.images.bucket
    AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.worker_sa_key.access_key
    AWS_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.worker_sa_key.secret_key
    S3_ENDPOINT           = "https://storage.yandexcloud.net"
  }

  depends_on = [
    yandex_kubernetes_cluster.main,
    yandex_kubernetes_node_group.cpu_nodes # ждём готовности кластера
  ]
}
