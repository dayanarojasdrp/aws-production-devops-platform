output "alb_security_group_id" {
  description = "Security group ID for the internet-facing ALB."
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS task network interfaces."
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "Security group ID for the private RDS instance."
  value       = aws_security_group.rds.id
}

output "security_group_ids" {
  description = "Security group IDs keyed by platform tier."
  value = {
    alb = aws_security_group.alb.id
    ecs = aws_security_group.ecs.id
    rds = aws_security_group.rds.id
  }
}
