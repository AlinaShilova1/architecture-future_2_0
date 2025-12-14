# Основные настройки проекта
project_name = "future-2-0"
environment  = "dev"

# Docker настройки
docker_host      = "unix:///var/run/docker.sock"
data_directory   = "/tmp/future-2-0-data"

# Сеть
network_subnet = "172.20.0.0/24"

# Порты сервисов
postgres_port                 = 5432
redis_port                    = 6379
minio_medical_port            = 9000
minio_medical_console_port    = 9001
minio_financial_port          = 9002
minio_financial_console_port  = 9003

# Kubernetes порты
portal_node_port = 30090

# Legacy системы
legacy_vm_count = 1

# Учетные данные
postgres_db_name = "metadata"
postgres_username = "admin"
minio_username = "admin"
