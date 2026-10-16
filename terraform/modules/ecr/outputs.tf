output "repository_arn" {
  description = "ARN used to scope future GitHub deployment permissions to this repository."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the private ECR repository."
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "Registry URL used to tag, push, pull, and deploy application images."
  value       = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  description = "AWS account registry ID that owns the repository."
  value       = aws_ecr_repository.this.registry_id
}
