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
