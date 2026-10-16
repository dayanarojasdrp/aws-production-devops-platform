output "database_instance_id" {
  description = "RDS PostgreSQL instance identifier."
  value       = aws_db_instance.this.identifier
}

output "database_endpoint" {
  description = "Private RDS hostname for the future ECS task definition."
  value       = aws_db_instance.this.address
}

output "database_port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Initial PostgreSQL database name."
  value       = aws_db_instance.this.db_name
}

output "database_subnet_group_name" {
  description = "DB subnet group spanning the private database subnets."
  value       = aws_db_subnet_group.this.name
}

output "credentials_secret_arn" {
  description = "Secret ARN that the future ECS execution role may read."
  value       = aws_secretsmanager_secret.database_credentials.arn
}

output "credentials_secret_name" {
  description = "Secrets Manager name containing the PostgreSQL username and password."
  value       = aws_secretsmanager_secret.database_credentials.name
}
