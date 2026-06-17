provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

provider "aws" {
  region                      = "ru-central1"
  endpoints                   = { s3 = "https://yandexcloud.net" }
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

provider "helm" {
  kubernetes {
    host                   = yandex_kubernetes_cluster.main.master[0].external_v4_endpoint
    cluster_ca_certificate = yandex_kubernetes_cluster.main.master[0].cluster_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "yc"
      args        = ["managed-kubernetes", "cluster", "get-credentials", yandex_kubernetes_cluster.main.id, "--external", "--force"]
    }
  }
}

# 1. Получаем актуальный токен авторизации Yandex Cloud
data "yandex_client_config" "client" {}

# 2. Связываем провайдер Kubernetes с вашим кластером "main"
provider "kubernetes" {
  host                   = yandex_kubernetes_cluster.main.master[0].external_v4_endpoint
  cluster_ca_certificate = yandex_kubernetes_cluster.main.master[0].cluster_ca_certificate
  token                  = data.yandex_client_config.client.iam_token
}

terraform {
  required_providers {
    # Провайдер для управления ресурсами Yandex Cloud
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }

    # Провайдер для управления манифестами внутри самого Kubernetes (секреты, поды и т.д.)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }
}

