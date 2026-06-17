output "postgres_host" {
  value = yandex_mdb_postgresql_cluster.pg.host[0].fqdn
}

output "s3_bucket_name" {
  value = yandex_storage_bucket.images.bucket
}

output "worker_sa_access_key" {
  value     = yandex_iam_service_account_static_access_key.worker_sa_key.access_key
  sensitive = true
}

output "worker_sa_secret_key" {
  value     = yandex_iam_service_account_static_access_key.worker_sa_key.secret_key
  sensitive = true
}

output "db_connection_string" {
  value     = "postgresql://${var.postgres_user}:${var.postgres_password}@${yandex_mdb_postgresql_cluster.pg.host[0].fqdn}:6432/${var.postgres_dbname}?sslmode=require"
  sensitive = true
}

output "s3_endpoint" {
  value = "https://storage.yandexcloud.net"
}

output "poll_interval" {
  value = 5
}

output "kubeconfig_command" {
  value = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.main.id} --external"
}

output "yc_cloud_id" {
  value = var.yc_cloud_id
}

output "yc_folder_id" {
  value = var.yc_folder_id
}

output "k8s_cluster_id" {
  value = yandex_kubernetes_cluster.main.id
}
