output "vpc_id" {
  description = "Development VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs containing the internet-facing ALB."
  value       = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs containing ECS tasks."
  value       = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Isolated database subnet IDs containing the RDS subnet group."
  value       = module.networking.private_db_subnet_ids
}

output "nat_gateway_ids" {
  description = "Development NAT Gateway IDs."
  value       = module.networking.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the development ALB."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for development ECS tasks."
  value       = module.security.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the development RDS instance."
  value       = module.security.rds_security_group_id
}

output "database_endpoint" {
  description = "Private development RDS hostname used by ECS tasks."
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
  description = "Secret ARN read by the development ECS execution role."
  value       = module.rds.credentials_secret_arn
}

output "ecr_repository_arn" {
  description = "Development ECR repository ARN used by the least-privilege ECS execution policy."
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

output "alb_arn" {
  description = "Development Application Load Balancer ARN."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "AWS-assigned public development ALB DNS name."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Development ALB canonical hosted zone ID used by its Route 53 alias."
  value       = module.alb.alb_zone_id
}

output "alb_http_listener_arn" {
  description = "Development HTTP listener ARN."
  value       = module.alb.http_listener_arn
}

output "alb_https_listener_arn" {
  description = "Development HTTPS listener ARN, or null while HTTPS is disabled."
  value       = module.alb.https_listener_arn
}

output "acm_certificate_arn" {
  description = "Development ACM certificate ARN, or null while HTTPS is disabled."
  value       = module.alb.certificate_arn
}

output "application_domain_name" {
  description = "Development API hostname, or null while HTTPS is disabled."
  value       = module.alb.application_domain_name
}

output "application_url" {
  description = "Canonical development HTTPS URL, or null while HTTPS is disabled."
  value       = module.alb.application_url
}

output "alb_target_group_arn" {
  description = "Development ECS target group ARN."
  value       = module.alb.target_group_arn
}

output "alb_target_group_name" {
  description = "Development ECS target group name used by AWS CLI health commands."
  value       = module.alb.target_group_name
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
