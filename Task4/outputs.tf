# Сеть
output "docker_network_name" {
  description = "Имя Docker сети"
  value       = docker_network.future_network.name
}

output "docker_network_subnet" {
  description = "Подсеть Docker сети"
  value       = docker_network.future_network.ipam_config[0].subnet
}

# Базы данных
output "postgres_connection" {
  description = "Данные для подключения к PostgreSQL"
  value = {
    host     = "localhost"
    port     = var.postgres_port
    database = var.postgres_db_name
    username = var.postgres_username
    password = random_password.postgres_password.result
  }
  sensitive = true
}

output "redis_connection" {
  description = "Данные для подключения к Redis"
  value = {
    host     = "localhost"
    port     = var.redis_port
    password = random_password.redis_password.result
  }
  sensitive = true
}

# Data Lakes
output "medical_data_lake" {
  description = "Данные медицинского Data Lake"
  value = {
    endpoint      = "http://localhost:${var.minio_medical_port}"
    console       = "http://localhost:${var.minio_medical_console_port}"
    username      = var.minio_username
    password      = random_password.minio_password.result
    bucket_policy = "Только для медицинских данных"
  }
}

output "financial_data_lake" {
  description = "Данные финансового Data Lake"
  value = {
    endpoint      = "http://localhost:${var.minio_financial_port}"
    console       = "http://localhost:${var.minio_financial_console_port}"
    username      = var.minio_username
    password      = random_password.minio_password.result
    bucket_policy = "Только для финансовых данных"
  }
}

# Kubernetes
output "kubernetes_cluster" {
  description = "Информация о Kubernetes кластере"
  value = {
    name       = "${var.project_name}-${var.environment}"
    kubeconfig = var.kubeconfig_path
    namespaces = {
      medical   = kubernetes_namespace.medical.metadata[0].name
      fintech   = kubernetes_namespace.fintech.metadata[0].name
      analytics = kubernetes_namespace.analytics.metadata[0].name
    }
  }
}

output "data_portal" {
  description = "Доступ к порталу данных"
  value = {
    name      = kubernetes_service.portal.metadata[0].name
    namespace = kubernetes_service.portal.metadata[0].namespace
    url       = "http://localhost:${var.portal_node_port}"
    type      = "NodePort"
  }
}

# Legacy системы
output "legacy_vms" {
  description = "Список legacy контейнеров"
  value = [
    for i in range(var.legacy_vm_count) : {
      name = "${var.project_name}-${var.environment}-legacy-vm-${i + 1}"
      status = "running"
    }
  ]
}

# Инструкции
output "infrastructure_summary" {
  description = "Сводка по развернутой инфраструктуре"
  value = <<-EOT
  ================================================================================
  ЛОКАЛЬНАЯ ИНФРАСТРУКТУРА "БУДУЩЕЕ 2.0" УСПЕШНО РАЗВЕРНУТА!
  
  АРХИТЕКТУРНЫЕ КОМПОНЕНТЫ:
  
  1. СЕТЬ (Аналог VPC):
     - Имя: ${docker_network.future_network.name}
     - Подсеть: ${docker_network.future_network.ipam_config[0].subnet}
  
  2. БАЗЫ ДАННЫХ (Аналог RDS/ElastiCache):
     - PostgreSQL (метаданные): localhost:${var.postgres_port}
       Пользователь: ${var.postgres_username}
     - Redis (кэш): localhost:${var.redis_port}
  
  3. DATA LAKES (Аналог S3):
     - Медицинский: http://localhost:${var.minio_medical_port}
       Консоль: http://localhost:${var.minio_medical_console_port}
     - Финансовый: http://localhost:${var.minio_financial_port}
       Консоль: http://localhost:${var.minio_financial_console_port}
  
  4. KUBERNETES КЛАСТЕР (Аналог EKS):
     - Имя: ${var.project_name}-${var.environment}
     - Namespaces: medical, fintech, analytics
  
  5. ПОРТАЛ ДАННЫХ:
     - URL: http://localhost:${var.portal_node_port}
  
  6. LEGACY СИСТЕМЫ (${var.legacy_vm_count} VM):
     ${join("\n     ", [for i in range(var.legacy_vm_count) : "- ${var.project_name}-${var.environment}-legacy-vm-${i + 1}"])}
  
  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:
  
  1. Проверить состояние контейнеров:
     docker ps --filter "label=project=${var.project_name}"
  
  2. Подключиться к Kubernetes:
     export KUBECONFIG="${var.kubeconfig_path}"
     kubectl get nodes
     kubectl get pods -A
  
  3. Проверить доступность сервисов:
     curl http://localhost:${var.portal_node_port}/health
  
  4. Уничтожить инфраструктуру:
     terraform destroy
  
  ПРИМЕЧАНИЕ: Это локальная эмуляция облачной архитектуры.
  В production-среде компоненты заменяются на AWS RDS, S3, EKS и т.д.
  ================================================================================
  EOT
}
