# Сервисный аккаунт для кластера
resource "yandex_iam_service_account" "k8s_sa" {
  name        = "k8s-cluster-sa"
  description = "Service account for Managed K8s cluster"
}

# Роли для кластера
resource "yandex_resourcemanager_folder_iam_member" "k8s_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

# Managed K8s кластер
resource "yandex_kubernetes_cluster" "main" {
  name       = "${var.project_name}-cluster"
  network_id = yandex_vpc_network.main.id

  master {
    zonal {
      zone      = var.yc_zone
      subnet_id = yandex_vpc_subnet.subnet_a.id
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_editor
  ]
}

# Сервисный аккаунт для группы узлов
resource "yandex_iam_service_account" "k8s_node_sa" {
  name        = "k8s-node-sa"
  description = "Service account for K8s node group"
}

# Роль для узлов (доступ к Container Registry и S3)
resource "yandex_resourcemanager_folder_iam_member" "k8s_node_puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# Группа CPU-узлов
resource "yandex_kubernetes_node_group" "cpu_nodes" {
  cluster_id = yandex_kubernetes_cluster.main.id
  name       = "cpu-node-group"

  instance_template {
    platform_id = "standard-v3"
    resources {
      cores  = 2
      memory = 4
    }
    boot_disk {
      type = "network-hdd"
      size = 64
    }
    network_interface {
      subnet_ids = [yandex_vpc_subnet.subnet_a.id]
      nat        = true
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }
}
