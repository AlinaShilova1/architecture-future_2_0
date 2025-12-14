# Сеть
output "docker_network_name" {
  description = "Имя Docker сети"
  value       = docker_network.future_network.name
}

output "docker_network_subnet" {
  description = "Подсеть Docker сети"
  value       = var.network_subnet
}

# Сервисы (без чувствительных данных)
output "services" {
  description = "Развернутые сервисы"
  value = {
    postgres = {
      host     = "localhost"
      port     = var.postgres_port
      database = var.postgres_db_name
    }
    redis = {
      host = "localhost"
      port = var.redis_port
    }
    minio_medical = {
      api      = "http://localhost:${var.minio_medical_port}"
      console  = "http://localhost:${var.minio_medical_console_port}"
    }
    minio_financial = {
      api      = "http://localhost:${var.minio_financial_port}"
      console  = "http://localhost:${var.minio_financial_console_port}"
    }
    data_portal = {
      url = "http://localhost:${var.portal_node_port}"
    }
    legacy_service = {
      name = docker_container.legacy_service.name
    }
  }
}

# Отдельный чувствительный output для паролей
output "sensitive_data" {
  description = "Чувствительные данные (пароли)"
  value = {
    postgres_password = random_password.postgres_password.result
    minio_password    = random_password.minio_password.result
    redis_password    = random_password.redis_password.result
  }
  sensitive = true
}

# Kubernetes манифесты
output "kubernetes_manifests" {
  description = "Созданные Kubernetes манифесты"
  value = [
    local_file.namespace_medical.filename,
    local_file.namespace_fintech.filename,
    local_file.namespace_analytics.filename,
    local_file.portal_deployment.filename
  ]
}

# Инструкции (без чувствительных данных)
output "infrastructure_summary" {
  description = "Сводка по развернутой инфраструктуре"
  value = <<-EOT
  ================================================================================
  ЛОКАЛЬНАЯ ИНФРАСТРУКТУРА "БУДУЩЕЕ 2.0"
  
  АРХИТЕКТУРНЫЕ КОМПОНЕНТЫ:
  
  1. СЕТЬ (Аналог VPC):
     - Имя: ${docker_network.future_network.name}
     - Подсеть: ${var.network_subnet}
  
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
  
  4. KUBERNETES РЕСУРСЫ:
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
  
  3. Применить Kubernetes манифесты (если установлен kubectl):
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

# URL для быстрого доступа
output "quick_access_urls" {
  description = "URL для быстрого доступа к сервисам"
  value = [
    "PostgreSQL: localhost:${var.postgres_port}",
    "Redis: localhost:${var.redis_port}",
    "MinIO Medical API: http://localhost:${var.minio_medical_port}",
    "MinIO Medical Console: http://localhost:${var.minio_medical_console_port}",
    "MinIO Financial API: http://localhost:${var.minio_financial_port}",
    "MinIO Financial Console: http://localhost:${var.minio_financial_console_port}",
    "Data Portal: http://localhost:${var.portal_node_port}"
  ]
}
