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
