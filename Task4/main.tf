terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.23" # Используем стабильную версию 2.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  
  # Локальные переменные для удобства
  locals {
  network_subnet = one([for config in docker_network.future_network.ipam_config : config.subnet])
  container_names = [
    docker_container.postgres_metadata.name,
    docker_container.redis_cache.name,
    docker_container.minio_medical.name,
    docker_container.minio_financial.name,
    docker_container.legacy_service.name
    ]
  }

  # Локальный бэкенд - состояние хранится в файле
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Генерация случайных паролей
resource "random_password" "postgres_password" {
  length  = 16
  special = false
}

resource "random_password" "minio_password" {
  length  = 16
  special = false
}

resource "random_password" "redis_password" {
  length  = 16
  special = false
}

# ==================== ПРОВАЙДЕРЫ ====================
provider "docker" {
  host = var.docker_host
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# ==================== DOCKER СЕТЬ (Аналог VPC) ====================
resource "docker_network" "future_network" {
  name = "${var.project_name}-${var.environment}-network"
  
  ipam_config {
    subnet  = var.network_subnet
    gateway = cidrhost(var.network_subnet, 1)
  }
  
  # В версии 2.x labels не поддерживаются для network
  # Можно использовать attrs как альтернативу
  # attrs = {
  #   "com.docker.compose.project" = var.project_name
  # }
}

# ==================== БАЗЫ ДАННЫХ (Аналог RDS) ====================
# PostgreSQL для центральных метаданных
resource "docker_container" "postgres_metadata" {
  name  = "${var.project_name}-${var.environment}-postgres-metadata"
  image = "postgres:15-alpine"
  
  env = [
    "POSTGRES_DB=${var.postgres_db_name}",
    "POSTGRES_USER=${var.postgres_username}",
    "POSTGRES_PASSWORD=${random_password.postgres_password.result}",
    "PGDATA=/var/lib/postgresql/data/pgdata"
  ]
  
  ports {
    internal = 5432
    external = var.postgres_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  volumes {
    container_path = "/var/lib/postgresql/data"
    host_path      = "${var.data_directory}/postgres"
  }
  
  restart = "unless-stopped"
  
  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.postgres_username}"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
  
  # В версии 2.x labels задаются через блок
  labels {
    label = "service"
    value = "database"
  }
  
  labels {
    label = "domain"
    value = "analytics"
  }
  
  labels {
    label = "database"
    value = "postgres"
  }
}

# Redis для кэширования
resource "docker_container" "redis_cache" {
  name  = "${var.project_name}-${var.environment}-redis-cache"
  image = "redis:7-alpine"
  
  command = ["redis-server", "--requirepass", random_password.redis_password.result]
  
  ports {
    internal = 6379
    external = var.redis_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  volumes {
    container_path = "/data"
    host_path      = "${var.data_directory}/redis"
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "cache"
  }
  
  labels {
    label = "domain"
    value = "shared"
  }
}

# ==================== DATA LAKE (Аналог S3) ====================
# MinIO для медицинского Data Lake
resource "docker_container" "minio_medical" {
  name  = "${var.project_name}-${var.environment}-minio-medical"
  image = "minio/minio:latest"
  
  command = ["server", "/data", "--console-address", ":9001"]
  
  env = [
    "MINIO_ROOT_USER=${var.minio_username}",
    "MINIO_ROOT_PASSWORD=${random_password.minio_password.result}",
    "MINIO_BROWSER=on"
  ]
  
  ports {
    internal = 9000
    external = var.minio_medical_port
  }
  ports {
    internal = 9001
    external = var.minio_medical_console_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  volumes {
    container_path = "/data"
    host_path      = "${var.data_directory}/minio-medical"
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "storage"
  }
  
  labels {
    label = "domain"
    value = "medical"
  }
  
  labels {
    label = "data-lake"
    value = "medical"
  }
}

# MinIO для финансового Data Lake
resource "docker_container" "minio_financial" {
  name  = "${var.project_name}-${var.environment}-minio-financial"
  image = "minio/minio:latest"
  
  command = ["server", "/data", "--console-address", ":9001"]
  
  env = [
    "MINIO_ROOT_USER=${var.minio_username}",
    "MINIO_ROOT_PASSWORD=${random_password.minio_password.result}"
  ]
  
  ports {
    internal = 9000
    external = var.minio_financial_port
  }
  ports {
    internal = 9001
    external = var.minio_financial_console_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  volumes {
    container_path = "/data"
    host_path      = "${var.data_directory}/minio-financial"
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "storage"
  }
  
  labels {
    label = "domain"
    value = "fintech"
  }
  
  labels {
    label = "data-lake"
    value = "financial"
  }
}

# ==================== KUBERNETES КЛАСТЕР (Аналог EKS) ====================
# Безопасный вариант - пропустим создание Kind если нет доступа
resource "null_resource" "setup_kubernetes" {
  triggers = {
    always_run = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Setting up local Kubernetes environment..."
      
      # Проверяем, установлен ли kind
      if command -v kind &> /dev/null; then
        echo "Kind is installed, checking for existing cluster..."
        
        if ! kind get clusters 2>/dev/null | grep -q "${var.project_name}-${var.environment}"; then
          echo "Creating Kind cluster: ${var.project_name}-${var.environment}"
          
          # Создаем конфигурационный файл
          cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${var.project_name}-${var.environment}

nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: ${var.k8s_http_port}
    protocol: TCP
  - containerPort: 30443
    hostPort: ${var.k8s_https_port}
    protocol: TCP
  - containerPort: 30090
    hostPort: ${var.portal_node_port}
    protocol: TCP

networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
EOF
          
          kind create cluster --config /tmp/kind-config.yaml --wait 5m
        else
          echo "Cluster ${var.project_name}-${var.environment} already exists"
        fi
      else
        echo "Kind is not installed. Kubernetes components will be simulated."
        echo "To install Kind: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/"
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}

# ==================== СИМУЛЯЦИЯ KUBERNETES РЕСУРСОВ ====================
# Вместо реальных Kubernetes ресурсов создаем файлы манифестов
resource "local_file" "namespace_medical" {
  filename = "${path.module}/k8s-manifests/namespace-medical.yaml"
  content  = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: medical
  labels:
    domain: medical
    managed-by: terraform
  annotations:
    description: "Пространство для медицинских сервисов"
EOT
}

resource "local_file" "namespace_fintech" {
  filename = "${path.module}/k8s-manifests/namespace-fintech.yaml"
  content  = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: fintech
  labels:
    domain: fintech
    managed-by: terraform
  annotations:
    description: "Пространство для финтех-сервисов"
EOT
}

resource "local_file" "namespace_analytics" {
  filename = "${path.module}/k8s-manifests/namespace-analytics.yaml"
  content  = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: analytics
  labels:
    domain: analytics
    managed-by: terraform
  annotations:
    description: "Пространство для аналитических сервисов"
EOT
}

resource "local_file" "portal_deployment" {
  filename = "${path.module}/k8s-manifests/portal-deployment.yaml"
  content  = <<-EOT
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-portal
  namespace: analytics
  labels:
    app: data-portal
    domain: analytics
    service: portal
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-portal
  template:
    metadata:
      labels:
        app: data-portal
    spec:
      containers:
      - name: portal
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: data-portal
  namespace: analytics
spec:
  selector:
    app: data-portal
  ports:
  - port: 80
    targetPort: 80
    nodePort: ${var.portal_node_port}
  type: NodePort
EOT
}

# ==================== СИМУЛЯЦИЯ ВИРТУАЛЬНЫХ МАШИН ====================
resource "docker_container" "legacy_service" {
  name  = "${var.project_name}-${var.environment}-legacy-service"
  image = "busybox:latest"
  
  command = ["sh", "-c", "echo 'Legacy service is running' && tail -f /dev/null"]
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  labels {
    label = "service"
    value = "legacy"
  }
  
  labels {
    label = "vm-type"
    value = "legacy-app"
  }
  
  labels {
    label = "managed-by"
    value = "terraform"
  }
  
  restart = "unless-stopped"
}
