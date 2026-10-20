output "vpc_id" {
  description = "Production VPC ID."
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
  description = "Production NAT Gateway IDs."
  value       = module.networking.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the production ALB."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for production ECS tasks."
  value       = module.security.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the production RDS instance."
  value       = module.security.rds_security_group_id
}

output "database_endpoint" {
  description = "Private production RDS hostname used by ECS tasks."
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
  description = "Secret ARN read by the production ECS execution role."
  value       = module.rds.credentials_secret_arn
}

output "ecr_repository_arn" {
  description = "Production ECR repository ARN used by the least-privilege ECS execution policy."
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

output "alb_arn" {
  description = "Production Application Load Balancer ARN."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "AWS-assigned public production ALB DNS name."
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Production ALB canonical hosted zone ID used by its Route 53 alias."
  value       = module.alb.alb_zone_id
}

output "alb_http_listener_arn" {
  description = "Production HTTP listener ARN."
  value       = module.alb.http_listener_arn
}

output "alb_https_listener_arn" {
  description = "Production HTTPS listener ARN, or null while HTTPS is disabled."
  value       = module.alb.https_listener_arn
}

output "acm_certificate_arn" {
  description = "Production ACM certificate ARN, or null while HTTPS is disabled."
  value       = module.alb.certificate_arn
}

output "application_domain_name" {
  description = "Production API hostname, or null while HTTPS is disabled."
  value       = module.alb.application_domain_name
}

output "application_url" {
  description = "Canonical production HTTPS URL, or null while HTTPS is disabled."
  value       = module.alb.application_url
}

output "alb_target_group_arn" {
  description = "Production ECS target group ARN."
  value       = module.alb.target_group_arn
}

output "alb_target_group_name" {
  description = "Production ECS target group name used by AWS CLI health commands."
  value       = module.alb.target_group_name
}

output "ecs_cluster_arn" {
  description = "Production ECS cluster ARN."
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Production ECS cluster name used by AWS CLI operational commands."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Production ECS service that maintains the API task count."
  value       = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  description = "Production API task definition ARN and revision."
  value       = module.ecs.task_definition_arn
}

output "ecs_execution_role_arn" {
  description = "Production role used by ECS to prepare and start tasks."
  value       = module.ecs.execution_role_arn
}

output "ecs_task_role_arn" {
  description = "Permission-free role exposed to the production API container."
  value       = module.ecs.task_role_arn
}

output "ecs_log_group_name" {
  description = "CloudWatch log group receiving production API stdout and stderr."
  value       = module.ecs.log_group_name
}

output "ecs_container_image" {
  description = "Exact immutable image registered in the production task definition."
  value       = module.ecs.container_image
}
