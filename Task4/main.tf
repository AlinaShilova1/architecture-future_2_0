terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
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
  
  labels = {
    project     = var.project_name
    environment = var.environment
    managed-by  = "terraform"
  }
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
  
  labels = {
    service  = "database"
    domain   = "analytics"
    database = "postgres"
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
  
  labels = {
    service = "cache"
    domain  = "shared"
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
  
  labels = {
    service    = "storage"
    domain     = "medical"
    data-lake  = "medical"
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
  
  labels = {
    service    = "storage"
    domain     = "fintech"
    data-lake  = "financial"
  }
}

# ==================== KUBERNETES КЛАСТЕР (Аналог EKS) ====================
# Создание Kind конфигурационного файла
resource "local_file" "kind_config" {
  filename = "${path.module}/kind-cluster.yaml"
  content  = <<-EOT
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
      
    networking:
      podSubnet: "10.244.0.0/16"
      serviceSubnet: "10.96.0.0/12"
      
    # Включение ingress controller
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
  EOT
}

# Создание кластера Kind через null_resource
resource "null_resource" "create_kind_cluster" {
  triggers = {
    config_content = local_file.kind_config.content
    always_run     = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Проверяем, существует ли кластер
      if ! kind get clusters | grep -q "${var.project_name}-${var.environment}"; then
        kind create cluster --config ${local_file.kind_config.filename} --wait 5m
      fi
      
      # Устанавливаем ingress-nginx
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
      
      # Ждем готовности ingress-nginx
      kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
  
  depends_on = [
    local_file.kind_config,
    docker_network.future_network
  ]
}

# ==================== KUBERNETES NAMESPACES ====================
resource "kubernetes_namespace" "medical" {
  metadata {
    name = "medical"
    
    labels = {
      domain     = "medical"
      managed-by = "terraform"
    }
    
    annotations = {
      description = "Пространство для медицинских сервисов"
    }
  }
  
  depends_on = [null_resource.create_kind_cluster]
}

resource "kubernetes_namespace" "fintech" {
  metadata {
    name = "fintech"
    
    labels = {
      domain     = "fintech"
      managed-by = "terraform"
    }
    
    annotations = {
      description = "Пространство для финтех-сервисов"
    }
  }
  
  depends_on = [null_resource.create_kind_cluster]
}

resource "kubernetes_namespace" "analytics" {
  metadata {
    name = "analytics"
    
    labels = {
      domain     = "analytics"
      managed-by = "terraform"
    }
    
    annotations = {
      description = "Пространство для аналитических сервисов"
    }
  }
  
  depends_on = [null_resource.create_kind_cluster]
}

# ==================== ПРИМЕР ПРИЛОЖЕНИЯ (Портал самообслуживания) ====================
# ConfigMap с конфигурацией
resource "kubernetes_config_map" "portal_config" {
  metadata {
    name      = "portal-config"
    namespace = kubernetes_namespace.analytics.metadata[0].name
  }
  
  data = {
    "app-config.json" = jsonencode({
      database = {
        host     = "host.docker.internal"
        port     = var.postgres_port
        name     = var.postgres_db_name
        user     = var.postgres_username
      }
      storage = {
        medical   = "http://host.docker.internal:${var.minio_medical_port}"
        financial = "http://host.docker.internal:${var.minio_financial_port}"
      }
      cache = {
        host = "host.docker.internal"
        port = var.redis_port
      }
    })
  }
  
  depends_on = [kubernetes_namespace.analytics]
}

# Deployment портала
resource "kubernetes_deployment" "portal" {
  metadata {
    name      = "data-portal"
    namespace = kubernetes_namespace.analytics.metadata[0].name
    
    labels = {
      app     = "data-portal"
      domain  = "analytics"
      service = "portal"
    }
  }
  
  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "data-portal"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "data-portal"
        }
      }
      
      spec {
        container {
          name  = "portal"
          image = "nginx:alpine"
          
          port {
            container_port = 80
          }
          
          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/nginx/conf.d/"
            read_only  = true
          }
          
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
        
        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.portal_config.metadata[0].name
          }
        }
      }
    }
  }
  
  depends_on = [kubernetes_config_map.portal_config]
}

# Service для портала
resource "kubernetes_service" "portal" {
  metadata {
    name      = "data-portal"
    namespace = kubernetes_namespace.analytics.metadata[0].name
  }
  
  spec {
    selector = {
      app = "data-portal"
    }
    
    port {
      port        = 80
      target_port = 80
      node_port   = var.portal_node_port
    }
    
    type = "NodePort"
  }
  
  depends_on = [kubernetes_deployment.portal]
}

# ==================== СИМУЛЯЦИЯ ВИРТУАЛЬНЫХ МАШИН ====================
# Docker контейнеры как "виртуальные машины" для legacy систем
resource "docker_container" "legacy_app_1" {
  count = var.legacy_vm_count >= 1 ? 1 : 0
  
  name  = "${var.project_name}-${var.environment}-legacy-vm-1"
  image = "alpine:latest"
  
  command = ["tail", "-f", "/dev/null"]
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  labels = {
    service   = "legacy"
    vm-type   = "legacy-app"
    managed-by = "terraform"
  }
  
  restart = "unless-stopped"
}

resource "docker_container" "legacy_app_2" {
  count = var.legacy_vm_count >= 2 ? 1 : 0
  
  name  = "${var.project_name}-${var.environment}-legacy-vm-2"
  image = "alpine:latest"
  
  command = ["tail", "-f", "/dev/null"]
  
  networks_advanced {
    name = docker_network.future_network.name
  }
  
  labels = {
    service   = "legacy"
    vm-type   = "legacy-app"
    managed-by = "terraform"
  }
  
  restart = "unless-stopped"
}
