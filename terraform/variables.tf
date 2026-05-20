# Обязательные переменные (пользователь должен задать в terraform.tfvars)
variable "sa_key_file" {
  description = "key.json"
  type        = string
  default     = "./key.json"
}

variable "yc_cloud_id" {
  description = "b1gojnvcqc43rk3ga3js"
  type        = string
}

variable "yc_folder_id" {
  description = "b1gkcc9dpl1g7jakckh1"
  type        = string
}

# Параметры инфраструктуры
variable "yc_zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-b"
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
  default     = "hybrid-gpu"
}

variable "postgres_user" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "worker"
}

variable "postgres_password" {
  description = "PostgreSQL admin password (обязательно задайте в terraform.tfvars)"
  type        = string
  sensitive   = true
}

variable "postgres_dbname" {
  description = "Database name for tasks queue"
  type        = string
  default     = "tasks"
}

variable "postgres_disk_size" {
  description = "PostgreSQL disk size in GB"
  type        = number
  default     = 20
}

variable "s3_bucket_name" {
  description = "S3 bucket name (если не задан, будет сгенерирован автоматически)"
  type        = string
  default     = ""
}

variable "yc_token" {
  description = "Yandex Cloud OAuth token (if not using yc CLI)"
  type        = string
  default     = "" # пустое значение по умолчанию
  sensitive   = true
}

variable "s3_access_key" { sensitive = true }
variable "s3_secret_key" { sensitive = true }
