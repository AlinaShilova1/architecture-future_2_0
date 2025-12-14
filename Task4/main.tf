terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.23"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ==================== ПРОВАЙДЕРЫ ====================
provider "docker" {
  host = var.docker_host
}

# ==================== DOCKER СЕТЬ (Аналог VPC) ====================
resource "docker_network" "future_network" {
  name = "${var.project_name}-${var.environment}-network"
  
  ipam_config {
    subnet  = var.network_subnet
    gateway = cidrhost(var.network_subnet, 1)
  }
}

# ==================== БАЗЫ ДАННЫХ (Аналог RDS) ====================
# PostgreSQL для центральных метаданных
resource "docker_container" "postgres_metadata" {
  name  = "${var.project_name}-${var.environment}-postgres-metadata"
  image = "postgres:15-alpine"
  
  env = [
    "POSTGRES_DB=metadata",
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=admin123",
    "PGDATA=/var/lib/postgresql/data/pgdata"
  ]
  
  ports {
    internal = 5432
    external = var.postgres_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "database"
  }
}

# Redis для кэширования
resource "docker_container" "redis_cache" {
  name  = "${var.project_name}-${var.environment}-redis-cache"
  image = "redis:7-alpine"
  
  command = ["redis-server", "--requirepass", "redis123"]
  
  ports {
    internal = 6379
    external = var.redis_port
  }
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "cache"
  }
}

# ==================== DATA LAKE (Аналог S3) ====================
# MinIO для медицинского Data Lake
resource "docker_container" "minio_medical" {
  name  = "${var.project_name}-${var.environment}-minio-medical"
  image = "minio/minio:latest"
  
  command = ["server", "/data", "--console-address", ":9001"]
  
  env = [
    "MINIO_ROOT_USER=admin",
    "MINIO_ROOT_PASSWORD=minio123",
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
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "storage"
  }
}

# MinIO для финансового Data Lake
resource "docker_container" "minio_financial" {
  name  = "${var.project_name}-${var.environment}-minio-financial"
  image = "minio/minio:latest"
  
  command = ["server", "/data", "--console-address", ":9001"]
  
  env = [
    "MINIO_ROOT_USER=admin",
    "MINIO_ROOT_PASSWORD=minio123"
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
  
  restart = "unless-stopped"
  
  labels {
    label = "service"
    value = "storage"
  }
}

# ==================== KUBERNETES МАНИФЕСТЫ (Аналог EKS) ====================
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

# ==================== LEGACY СИСТЕМЫ ====================
resource "docker_container" "legacy_service" {
  name  = "${var.project_name}-${var.environment}-legacy-service"
  image = "busybox:latest"
  
  command = ["sh", "-c", "echo 'Legacy service is running' && tail -f /dev/null"]
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  restart = "unless-stopped"
}
