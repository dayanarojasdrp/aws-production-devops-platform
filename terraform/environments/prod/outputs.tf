output "vpc_id" {
  description = "Production VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the future internet-facing ALB."
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs for future ECS tasks."
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Isolated database subnet IDs for the future RDS subnet group."
  value       = module.networking.private_db_subnet_ids
}

output "nat_gateway_ids" {
  description = "Production NAT Gateway IDs."
  value       = module.networking.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the future production ALB."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for future production ECS tasks."
  value       = module.security.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the future production RDS instance."
  value       = module.security.rds_security_group_id
}

output "database_endpoint" {
  description = "Private production RDS hostname for future ECS tasks."
  value       = module.rds.database_endpoint
}

output "database_port" {
  description = "Production PostgreSQL listener port."
  value       = module.rds.database_port
}

output "database_name" {
  description = "Production PostgreSQL database name."
  value       = module.rds.database_name
}

output "database_credentials_secret_arn" {
  description = "Secret ARN for the future production ECS execution role."
  value       = module.rds.credentials_secret_arn
}

output "ecr_repository_arn" {
  description = "Production ECR repository ARN for future least-privilege IAM policies."
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "Production ECR repository name."
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "Production ECR URL used to tag, push, and deploy application images."
  value       = module.ecr.repository_url
}
