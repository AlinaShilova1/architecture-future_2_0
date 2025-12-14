# Основные настройки
project_name = "future-2-0"
environment  = "dev"
aws_region   = "eu-central-1"

# VPC настройки
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-central-1a", "eu-central-1b"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

# EKS настройки
k8s_version = "1.27"
node_instance_types = ["t3.medium", "t3.large"]
node_min_size = 2
node_max_size = 6
node_desired_size = 3
node_disk_size = 50

# Базы данных
rds_instance_type = "db.t3.medium"
db_username = "admin"
db_password = "ChangeThisPassword123!" # В продакшене используется секреты
redis_node_type = "cache.t3.micro"

# Виртуальные машины
legacy_vm_count = 2
legacy_vm_instance_type = "t3.medium"

# Теги
common_tags = {
  Project     = "Future-2.0"
  ManagedBy   = "Terraform"
  Environment = "dev"
  CostCenter  = "IT"
  Department  = "Platform"
}
