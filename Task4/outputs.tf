# Сеть
output "docker_network_name" {
  description = "Имя Docker сети"
  value       = docker_network.future_network.name
}

output "docker_network_subnet" {
  description = "Подсеть Docker сети"
  value       = var.network_subnet
}

# Контейнеры
output "container_names" {
  description = "Имена созданных контейнеров"
  value = [
    "postgres-metadata",
    "redis-cache", 
    "minio-medical",
    "minio-financial",
    "legacy-service"
  ]
}

# Сервисы
output "service_endpoints" {
  description = "Endpoint'ы сервисов"
  value = <<-EOT
  PostgreSQL: localhost:${var.postgres_port}
  Redis: localhost:${var.redis_port}
  MinIO Medical: http://localhost:${var.minio_medical_port}
  MinIO Medical Console: http://localhost:${var.minio_medical_console_port}
  MinIO Financial: http://localhost:${var.minio_financial_port}
  MinIO Financial Console: http://localhost:${var.minio_financial_console_port}
  Data Portal: http://localhost:${var.portal_node_port}
  EOT
}

# Kubernetes манифесты
output "kubernetes_manifests" {
  description = "Пути к созданным Kubernetes манифестам"
  value = [
    "k8s-manifests/namespace-medical.yaml",
    "k8s-manifests/namespace-fintech.yaml", 
    "k8s-manifests/namespace-analytics.yaml",
    "k8s-manifests/portal-deployment.yaml"
  ]
}

# Инструкции
output "instructions" {
  description = "Инструкции по использованию"
  value = <<-EOT
  Инфраструктура "Будущее 2.0" развернута!
  
  Компоненты:
  - Сеть Docker: ${docker_network.future_network.name}
  - База данных: PostgreSQL на порту ${var.postgres_port}
  - Кэш: Redis на порту ${var.redis_port}
  - Data Lakes: MinIO на портах ${var.minio_medical_port} и ${var.minio_financial_port}
  - Портал данных: http://localhost:${var.portal_node_port}
  
  Для управления используйте:
  docker ps
  docker network inspect ${docker_network.future_network.name}
  EOT
}
