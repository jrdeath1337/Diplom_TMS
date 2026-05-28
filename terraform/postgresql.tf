# Кластер Managed PostgreSQL для очереди задач
resource "yandex_mdb_postgresql_cluster" "pg" {
  name               = "${var.project_name}-pg"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.main.id
  security_group_ids = [yandex_vpc_security_group.postgres_sg.id] # ← добавлено

  config {
    version = "16"
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = var.postgres_disk_size
    }
    postgresql_config = {
      max_connections = 100
    }
  }

  host {
    zone             = var.yc_zone
    subnet_id        = yandex_vpc_subnet.subnet_a.id
    assign_public_ip = true
  }
}

# Пользователь
resource "yandex_mdb_postgresql_user" "worker" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = var.postgres_user
  password   = var.postgres_password
  grants     = ["mdb_admin"]
}

# База данных
resource "yandex_mdb_postgresql_database" "tasks_db" {
  cluster_id = yandex_mdb_postgresql_cluster.pg.id
  name       = var.postgres_dbname
  owner      = var.postgres_user
  depends_on = [yandex_mdb_postgresql_user.worker]
}

# Автоматическое создание таблицы tasks
resource "null_resource" "create_tasks_table" {
  depends_on = [
    yandex_mdb_postgresql_database.tasks_db,
    yandex_mdb_postgresql_user.worker
  ]

  provisioner "local-exec" {
    command = <<-EOT
      PGPASSWORD=${var.postgres_password} psql \
        -h ${yandex_mdb_postgresql_cluster.pg.host[0].fqdn} \
        -p 6432 \
        -U ${var.postgres_user} \
        -d ${var.postgres_dbname} \
        -c "CREATE TABLE IF NOT EXISTS tasks (
            id SERIAL PRIMARY KEY,
            payload JSONB NOT NULL,
            status VARCHAR(20) DEFAULT 'pending',
            result_url TEXT,
            error_msg TEXT,
            created_at TIMESTAMP DEFAULT now(),
            updated_at TIMESTAMP DEFAULT now()
          );"
    EOT
  }
}
