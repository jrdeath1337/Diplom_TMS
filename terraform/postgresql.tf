# Кластер Managed PostgreSQL для очереди задач
resource "yandex_mdb_postgresql_cluster" "pg" {
  name               = "${var.project_name}-pg"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.main.id
  security_group_ids = []

  # Блок config: здесь указываются ресурсы хостов, версия БД и т.д.
  config {
    # Версия PostgreSQL теперь указывается здесь, внутри блока config!
    version = "16"
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = var.postgres_disk_size
    }
    # Дополнительные параметры БД (опционально)
    postgresql_config = {
      max_connections = 100
    }
  }

  host {
    zone             = var.yc_zone
    subnet_id        = yandex_vpc_subnet.subnet_a.id
    assign_public_ip = true # для подключения из интернета (если нет VPN)
  }
}
# Пользователь создается отдельным ресурсом
resource "yandex_mdb_postgresql_user" "worker" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = var.postgres_user
  password   = var.postgres_password
  grants     = ["mdb_admin"]
}

resource "yandex_mdb_postgresql_database" "tasks_db" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = var.postgres_dbname
  owner      = var.postgres_user

  depends_on = [yandex_mdb_postgresql_user.worker]
}

