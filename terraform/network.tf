# Сеть и подсеть
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

# Security group для PostgreSQL (одна!)
resource "yandex_vpc_security_group" "postgres_sg" {
  name        = "${var.project_name}-postgres-sg"
  description = "Allow PostgreSQL access from specific IPs"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    description    = "PostgreSQL from allowed CIDR"
    v4_cidr_blocks = [var.postgres_allowed_cidr]
    port           = 6432
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  labels = {
    project    = var.project_name
    env        = "diploma"
    managed_by = "terraform"
  }
}
