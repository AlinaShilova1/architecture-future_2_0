# VPC outputs
output "vpc_id" {
  description = "ID созданной VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Список приватных подсетей"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Список публичных подсетей"
  value       = module.vpc.public_subnets
}

# EKS outputs
output "eks_cluster_name" {
  description = "Имя EKS кластера"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint EKS кластера"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security Group ID кластера"
  value       = module.eks.cluster_security_group_id
}

output "kubeconfig" {
  description = "Команда для настройки kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
  sensitive   = false
}

# Database outputs
output "rds_endpoint" {
  description = "Endpoint RDS инстанса"
  value       = aws_db_instance.central_metadata.endpoint
}

output "rds_connection_string" {
  description = "Строка подключения к PostgreSQL"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.central_metadata.endpoint}/${aws_db_instance.central_metadata.db_name}"
  sensitive   = true
}

output "redis_endpoint" {
  description = "Endpoint Redis кластера"
  value       = aws_elasticache_cluster.redis_cache.cache_nodes[0].address
}

# Data Lake outputs
output "medical_data_lake_bucket" {
  description = "Имя бакета Medical Data Lake"
  value       = aws_s3_bucket.medical_data_lake.bucket
}

output "financial_data_lake_bucket" {
  description = "Имя бакета Financial Data Lake"
  value       = aws_s3_bucket.financial_data_lake.bucket
}

output "s3_bucket_arns" {
  description = "ARN бакетов S3"
  value = {
    medical   = aws_s3_bucket.medical_data_lake.arn
    financial = aws_s3_bucket.financial_data_lake.arn
  }
}

# Load Balancer outputs
output "lb_dns_name" {
  description = "DNS имя Load Balancer"
  value       = aws_lb.main.dns_name
}

output "lb_zone_id" {
  description = "Zone ID Load Balancer"
  value       = aws_lb.main.zone_id
}

# Security outputs
output "security_group_ids" {
  description = "ID Security Groups"
  value = {
    rds    = aws_security_group.rds_sg.id
    redis  = aws_security_group.redis_sg.id
    lb     = aws_security_group.lb_sg.id
    vm     = aws_security_group.vm_sg.id
  }
}

# IAM outputs
output "medical_sa_role_arn" {
  description = "ARN роли для medical service account"
  value       = aws_iam_role.medical_sa_role.arn
}

# Инструкции для следующего шага
output "next_steps" {
  description = "Инструкции по следующим шагам"
  value = <<-EOT
    Infrastructure deployed successfully!
    
    Next steps:
    1. Configure kubectl: ${module.eks.cluster_name}
    2. Deploy applications using Helm/ArgoCD
    3. Configure monitoring (Prometheus/Grafana)
    4. Set up CI/CD pipelines
    
    Access endpoints:
    - Kubernetes: ${module.eks.cluster_endpoint}
    - PostgreSQL: ${aws_db_instance.central_metadata.endpoint}
    - Redis: ${aws_elasticache_cluster.redis_cache.cache_nodes[0].address}
    - Load Balancer: ${aws_lb.main.dns_name}
    
    Medical Data Lake: s3://${aws_s3_bucket.medical_data_lake.bucket}
    Financial Data Lake: s3://${aws_s3_bucket.financial_data_lake.bucket}
  EOT
}
