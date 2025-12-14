# Конфигурация Terraform
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    bucket         = "future-2-0-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Провайдер AWS
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Future-2.0"
      ManagedBy   = "Terraform"
      CostCenter  = "IT"
    }
  }
}

# Провайдер Kubernetes (будет настроен после создания EKS)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Data source для аутентификации EKS
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ==================== МОДУЛЬ VPC ====================
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr
  
  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# ==================== МОДУЛЬ EKS ====================
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.k8s_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # IAM роль для EKS
  cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr
  
  # Узлы EKS
  eks_managed_node_groups = {
    main = {
      name           = "main-node-group"
      instance_types = var.node_instance_types
      
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      
      disk_size = var.node_disk_size
      
      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.project_name}-${var.environment}" = "owned"
      }
    }
    
    medical = {
      name           = "medical-node-group"
      instance_types = ["m5.2xlarge"] # Для ресурсоемких ИИ-задач
      
      min_size     = 2
      max_size     = 6
      desired_size = 2
      
      disk_size = 100
      
      labels = {
        "domain" = "medical"
      }
      
      taints = [{
        key    = "domain"
        value  = "medical"
        effect = "NO_SCHEDULE"
      }]
    }
  }
  
  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 1025
      to_port                       = 65535
      source_cluster_security_group = true
      description                   = "Allow traffic from control plane to worker nodes"
    }
  }
}

# ==================== УПРАВЛЯЕМЫЕ БАЗЫ ДАННЫХ ====================
# PostgreSQL для метаданных и справочников
resource "aws_db_instance" "central_metadata" {
  identifier     = "${var.project_name}-${var.environment}-metadata"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = var.rds_instance_type
  
  allocated_storage     = 100
  storage_encrypted     = true
  storage_type         = "gp3"
  max_allocated_storage = 500
  
  db_name  = "metadata"
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment == "prod" ? false : true
  
  tags = {
    Name        = "Central Metadata Database"
    Application = "Future-2.0"
    Domain      = "analytics"
  }
}

# Redis для кэширования
resource "aws_elasticache_cluster" "redis_cache" {
  cluster_id           = "${var.project_name}-${var.environment}-redis"
  engine              = "redis"
  node_type           = var.redis_node_type
  num_cache_nodes     = 1
  parameter_group_name = "default.redis7"
  port                = 6379
  
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis_sg.id]
  
  tags = {
    Name = "Redis Cache Cluster"
  }
}

# ==================== DATA LAKE (S3) ====================
resource "aws_s3_bucket" "medical_data_lake" {
  bucket = "${var.project_name}-${var.environment}-medical-data"
  
  tags = {
    Name        = "Medical Data Lake"
    Domain      = "medical"
    Sensitivity = "high"
  }
}

resource "aws_s3_bucket" "financial_data_lake" {
  bucket = "${var.project_name}-${var.environment}-financial-data"
  
  tags = {
    Name        = "Financial Data Lake"
    Domain      = "fintech"
    Sensitivity = "high"
  }
}

# Включение шифрования и версионирования для Data Lakes
resource "aws_s3_bucket_server_side_encryption_configuration" "medical_encryption" {
  bucket = aws_s3_bucket.medical_data_lake.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "medical_versioning" {
  bucket = aws_s3_bucket.medical_data_lake.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Аналогично для финансового Data Lake...

# ==================== LOAD BALANCER ====================
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-lb"
  internal           = false
  load_balancer_type = "application"
  
  security_groups = [aws_security_group.lb_sg.id]
  subnets         = module.vpc.public_subnets
  
  enable_deletion_protection = var.environment == "prod"
  
  tags = {
    Name = "Main Application Load Balancer"
  }
}

# ==================== ВИРТУАЛЬНЫЕ МАШИНЫ (для legacy/stateful) ====================
resource "aws_instance" "legacy_app_server" {
  count         = var.legacy_vm_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.legacy_vm_instance_type
  
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.vm_sg.id]
  
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }
  
  tags = {
    Name    = "${var.project_name}-${var.environment}-legacy-vm-${count.index + 1}"
    Purpose = "Legacy Application Host"
  }
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io
              EOF
  
  lifecycle {
    ignore_changes = [user_data]
  }
}

# ==================== SECURITY GROUPS ====================
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "RDS Security Group"
  }
}

# Создаем остальные Security Groups аналогично...

# ==================== ВСПОМОГАТЕЛЬНЫЕ РЕСУРСЫ ====================
# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
  
  tags = {
    Name = "Main DB Subnet Group"
  }
}

# Elasticache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# Data source для последнего AMI Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  owners = ["099720109477"] # Canonical
}

# IAM роли для сервис-аккаунтов (пример)
resource "aws_iam_role" "medical_sa_role" {
  name = "${var.project_name}-${var.environment}-medical-sa-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:medical:default"
          }
        }
      }
    ]
  })
  
  tags = {
    Domain = "medical"
  }
}

# Привязка политик к роли
resource "aws_iam_role_policy_attachment" "medical_s3_access" {
  role       = aws_iam_role.medical_sa_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
