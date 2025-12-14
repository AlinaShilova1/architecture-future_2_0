# Основные переменные проекта
variable "project_name" {
  description = "Название проекта"
  type        = string
  default     = "future-2-0"
}

variable "environment" {
  description = "Окружение (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS регион"
  type        = string
  default     = "eu-central-1"
}

# VPC переменные
variable "vpc_cidr" {
  description = "CIDR блок для VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Список availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR блоки для приватных подсетей"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR блоки для публичных подсетей"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EKS переменные
variable "k8s_version" {
  description = "Версия Kubernetes"
  type        = string
  default     = "1.27"
}

variable "cluster_service_ipv4_cidr" {
  description = "CIDR для сервисов Kubernetes"
  type        = string
  default     = "172.20.0.0/16"
}

variable "node_instance_types" {
  description = "Типы инстансов для worker nodes"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "node_min_size" {
  description = "Минимальное количество worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Максимальное количество worker nodes"
  type        = number
  default     = 10
}

variable "node_desired_size" {
  description = "Желаемое количество worker nodes"
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Размер диска для worker nodes (GB)"
  type        = number
  default     = 50
}

# Базы данных переменные
variable "rds_instance_type" {
  description = "Тип инстанса RDS"
  type        = string
  default     = "db.t3.large"
}

variable "db_username" {
  description = "Имя пользователя БД"
  type        = string
  default     = "admin"
  
  sensitive = true
}

variable "db_password" {
  description = "Пароль пользователя БД"
  type        = string
  
  sensitive = true
}

variable "redis_node_type" {
  description = "Тип ноды Redis"
  type        = string
  default     = "cache.t3.micro"
}

# Виртуальные машины переменные
variable "legacy_vm_count" {
  description = "Количество legacy VM"
  type        = number
  default     = 2
}

variable "legacy_vm_instance_type" {
  description = "Тип инстанса для legacy VM"
  type        = string
  default     = "t3.medium"
}

# Теги
variable "common_tags" {
  description = "Общие теги для всех ресурсов"
  type        = map(string)
  default = {
    Project     = "Future-2.0"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
