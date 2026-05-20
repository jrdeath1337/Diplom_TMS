# Сеть и подсеть для PostgreSQL (и для будущего K8s, если добавите)
resource "yandex_vpc_network" "main" {
  name        = "${var.project_name}-network"
  description = "Network for hybrid GPU project"
}

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.project_name}-subnet-a"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.0.0/24"]
  description    = "Subnet in ru-central1-a"
}
