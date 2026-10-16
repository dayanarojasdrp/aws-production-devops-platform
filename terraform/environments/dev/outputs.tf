output "vpc_id" {
  description = "Development VPC ID."
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
  description = "Development NAT Gateway IDs."
  value       = module.networking.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the future development ALB."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for future development ECS tasks."
  value       = module.security.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the future development RDS instance."
  value       = module.security.rds_security_group_id
}

output "database_endpoint" {
  description = "Private development RDS hostname for future ECS tasks."
  value       = module.rds.database_endpoint
}

output "database_port" {
  description = "Development PostgreSQL listener port."
  value       = module.rds.database_port
}

output "database_name" {
  description = "Development PostgreSQL database name."
  value       = module.rds.database_name
}

output "database_credentials_secret_arn" {
  description = "Secret ARN for the future development ECS execution role."
  value       = module.rds.credentials_secret_arn
}

output "ecr_repository_arn" {
  description = "Development ECR repository ARN for future least-privilege IAM policies."
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "Development ECR repository name."
  value       = module.ecr.repository_name
}

output "ecr_repository_url" {
  description = "Development ECR URL used to tag, push, and deploy application images."
  value       = module.ecr.repository_url
}

output "ecs_cluster_arn" {
  description = "Development ECS cluster ARN."
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Development ECS cluster name used by AWS CLI operational commands."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Development ECS service that maintains the API task count."
  value       = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  description = "Development API task definition ARN and revision."
  value       = module.ecs.task_definition_arn
}

output "ecs_execution_role_arn" {
  description = "Development role used by ECS to prepare and start tasks."
  value       = module.ecs.execution_role_arn
}

output "ecs_task_role_arn" {
  description = "Permission-free role exposed to the development API container."
  value       = module.ecs.task_role_arn
}

output "ecs_log_group_name" {
  description = "CloudWatch log group receiving development API stdout and stderr."
  value       = module.ecs.log_group_name
}

output "ecs_container_image" {
  description = "Exact immutable image registered in the development task definition."
  value       = module.ecs.container_image
}
