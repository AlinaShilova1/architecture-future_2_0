# Сеть
output "docker_network_name" {
  description = "Имя Docker сети"
  value       = docker_network.future_network.name
}

output "docker_network_subnet" {
  description = "Подсеть Docker сети"
  value       = one([for config in docker_network.future_network.ipam_config : config.subnet])
}

# Базы данных
output "postgres_connection" {
  description = "Данные для подключения к PostgreSQL"
  value = {
    host     = "localhost"
    port     = var.postgres_port
    database = var.postgres_db_name
    username = var.postgres_username
  }
  sensitive = true
}

output "redis_connection" {
  description = "Данные для подключения к Redis"
  value = {
    host     = "localhost"
    port     = var.redis_port
  }
}

# Data Lakes
output "medical_data_lake_endpoints" {
  description = "Endpoint'ы медицинского Data Lake"
  value = {
    api      = "http://localhost:${var.minio_medical_port}"
    console  = "http://localhost:${var.minio_medical_console_port}"
  }
}

output "financial_data_lake_endpoints" {
  description = "Endpoint'ы финансового Data Lake"
  value = {
    api      = "http://localhost:${var.minio_financial_port}"
    console  = "http://localhost:${var.minio_financial_console_port}"
  }
}

# Kubernetes
output "kubernetes_manifests" {
  description = "Созданные Kubernetes манифесты"
  value = [
    local_file.namespace_medical.filename,
    local_file.namespace_fintech.filename,
    local_file.namespace_analytics.filename,
    local_file.portal_deployment.filename
  ]
}

output "data_portal_url" {
  description = "URL портала данных"
  value       = "http://localhost:${var.portal_node_port}"
}

# Инструкции
output "infrastructure_summary" {
  description = "Сводка по развернутой инфраструктуре"
  value = <<-EOT
  ================================================================================
  ЛОКАЛЬНАЯ ИНФРАСТРУКТУРА "БУДУЩЕЕ 2.0"
  
  АРХИТЕКТУРНЫЕ КОМПОНЕНТЫ:
  
  1. СЕТЬ (Аналог VPC):
     - Имя: ${docker_network.future_network.name}
     - Подсеть: ${one([for config in docker_network.future_network.ipam_config : config.subnet])}
  
  2. БАЗЫ ДАННЫХ (Аналог RDS/ElastiCache):
     - PostgreSQL (метаданные): localhost:${var.postgres_port}
       База данных: ${var.postgres_db_name}
     - Redis (кэш): localhost:${var.redis_port}
  
  3. DATA LAKES (Аналог S3):
     - Медицинский: 
       API: http://localhost:${var.minio_medical_port}
       Консоль: http://localhost:${var.minio_medical_console_port}
     - Финансовый:
       API: http://localhost:${var.minio_financial_port}
       Консоль: http://localhost:${var.minio_financial_console_port}
  
  4. KUBERNETES КЛАСТЕР (Аналог EKS):
     - Манифесты созданы в папке: k8s-manifests/
     - Namespaces: medical, fintech, analytics
  
  5. ПОРТАЛ ДАННЫХ:
     - URL: http://localhost:${var.portal_node_port}
  
  6. LEGACY СИСТЕМЫ:
     - Legacy сервис: ${docker_container.legacy_service.name}
  
  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:
  
  1. Проверить состояние контейнеров:
     docker ps
  
  2. Проверить сеть:
     docker network inspect ${docker_network.future_network.name}
  
  3. Применить Kubernetes манифесты:
     kubectl apply -f k8s-manifests/
  
  4. Проверить доступность портала:
     curl http://localhost:${var.portal_node_port}
  
  5. Уничтожить инфраструктуру:
     terraform destroy
  
  ПРИМЕЧАНИЕ: Это локальная эмуляция облачной архитектуры.
  В production-среде компоненты заменяются на AWS RDS, S3, EKS и т.д.
  ================================================================================
  EOT
}
