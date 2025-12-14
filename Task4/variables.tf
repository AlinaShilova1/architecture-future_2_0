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

# Docker настройки
variable "docker_host" {
  description = "Docker host (Unix socket или TCP)"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "data_directory" {
  description = "Базовый путь для хранения данных на хосте"
  type        = string
  default     = "/tmp/future-2-0-data"
}

# Сеть
variable "network_subnet" {
  description = "CIDR подсеть для Docker сети"
  type        = string
  default     = "172.20.0.0/24"
}

# Порты сервисов
variable "postgres_port" {
  description = "Порт PostgreSQL"
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Порт Redis"
  type        = number
  default     = 6379
}

variable "minio_medical_port" {
  description = "Порт MinIO медицинского Data Lake"
  type        = number
  default     = 9000
}

variable "minio_medical_console_port" {
  description = "Порт консоли MinIO медицинского Data Lake"
  type        = number
  default     = 9001
}

variable "minio_financial_port" {
  description = "Порт MinIO финансового Data Lake"
  type        = number
  default     = 9002
}

variable "minio_financial_console_port" {
  description = "Порт консоли MinIO финансового Data Lake"
  type        = number
  default     = 9003
}

# Kubernetes порты
variable "k8s_http_port" {
  description = "HTTP порт для Kubernetes ingress"
  type        = number
  default     = 30080
}

variable "k8s_https_port" {
  description = "HTTPS порт для Kubernetes ingress"
  type        = number
  default     = 30443
}

variable "portal_node_port" {
  description = "NodePort для портала данных"
  type        = number
  default     = 30090
}

# Kubernetes настройки
variable "kubeconfig_path" {
  description = "Путь к kubeconfig файлу"
  type        = string
  default     = "~/.kube/config"
}

# Legacy системы
variable "legacy_vm_count" {
  description = "Количество legacy контейнеров (виртуальных машин)"
  type        = number
  default     = 2
  
  validation {
    condition     = var.legacy_vm_count >= 0 && var.legacy_vm_count <= 4
    error_message = "Legacy VM count must be between 0 and 4."
  }
}

# Учетные данные БД
variable "postgres_db_name" {
  description = "Имя базы данных PostgreSQL"
  type        = string
  default     = "metadata"
  
  sensitive = true
}

variable "postgres_username" {
  description = "Имя пользователя PostgreSQL"
  type        = string
  default     = "admin"
  
  sensitive = true
}

variable "minio_username" {
  description = "Имя пользователя MinIO"
  type        = string
  default     = "admin"
  
  sensitive = true
}

# Пароли будут сгенерированы автоматически через random_password
