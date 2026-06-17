resource "yandex_container_registry" "default" {
  name      = "${var.project_name}-registry"
  folder_id = var.yc_folder_id
  labels    = { project = var.project_name }
}

resource "yandex_resourcemanager_folder_iam_member" "registry_puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# Опционально: дать сервисному аккаунту кластера права на push (для CI/CD)
resource "yandex_resourcemanager_folder_iam_member" "registry_pusher" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.pusher"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}
