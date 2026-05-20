provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

provider "aws" {
  region                      = "ru-central1"
  endpoints                   = { s3 = "https://storage.yandexcloud.net" }
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  access_key                  = var.s3_access_key
  secret_key                  = var.s3_secret_key
}
