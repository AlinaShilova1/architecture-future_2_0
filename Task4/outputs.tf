# Сеть
output "docker_network_name" {
  description = "Имя Docker сети"
  value       = docker_network.future_network.name
}

output "docker_network_subnet" {
  description = "Подсеть Docker сети"
  value       = docker_network.future_network.ipam_config[0].subnet
}

# Сервисы
output "services" {
  description = "Развернутые сервисы"
  value = {
    postgres = {
      host = "localhost"
      port = var.postgres_port
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
  }
}

# Инструкции
output "instructions" {
  description = "Инструкции по использованию"
  value = <<-EOT
  ================================================================================
  ЛОКАЛЬНАЯ ИНФРАСТРУКТУРА "БУДУЩЕЕ 2.0"
  
  Развернутые компоненты:
  1. Сеть Docker: ${docker_network.future_network.name}
  2. База данных PostgreSQL: localhost:${var.postgres_port}
  3. Кэш Redis: localhost:${var.redis_port}
  4. Медицинский Data Lake (MinIO):
     - API: http://localhost:${var.minio_medical_port}
     - Консоль: http://localhost:${var.minio_medical_console_port}
  5. Финансовый Data Lake (MinIO):
     - API: http://localhost:${var.minio_financial_port}
     - Консоль: http://localhost:${var.minio_financial_console_port}
  6. Портал данных: http://localhost:${var.portal_node_port}
  
  Kubernetes манифесты созданы в папке k8s-manifests/
  
  Команды для проверки:
  docker ps
  docker network inspect ${docker_network.future_network.name}
  
  Для применения Kubernetes манифестов (если установлен kubectl):
  kubectl apply -f k8s-manifests/
  ================================================================================
  EOT
}
