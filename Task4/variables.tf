variable "project_name" {
  description = "Название проекта"
  type        = string
  default     = "future-2-0"
}

variable "environment" {
  description = "Окружение"
  type        = string
  default     = "dev"
}

variable "docker_host" {
  description = "Docker host"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "network_subnet" {
  description = "CIDR подсеть для Docker сети"
  type        = string
  default     = "172.20.0.0/24"
}

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

variable "portal_node_port" {
  description = "NodePort для портала данных"
  type        = number
  default     = 30090
}
