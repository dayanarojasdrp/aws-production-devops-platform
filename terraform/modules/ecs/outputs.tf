output "cluster_arn" {
  description = "ARN of the ECS cluster that organizes the application service."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.application.id
}

output "service_name" {
  description = "Name of the ECS service that maintains the desired task count."
  value       = aws_ecs_service.application.name
}

output "task_definition_arn" {
  description = "ARN including the active task definition revision."
  value       = aws_ecs_task_definition.application.arn
}

output "task_definition_family" {
  description = "Stable family name shared by task definition revisions."
  value       = aws_ecs_task_definition.application.family
}

output "execution_role_arn" {
  description = "Role used by ECS to pull the image, read the database secret, and publish logs."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "Permission-free role exposed to the application container."
  value       = aws_iam_role.task.arn
}

output "log_group_arn" {
  description = "ARN of the CloudWatch application log group."
  value       = aws_cloudwatch_log_group.application.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch application log group."
  value       = aws_cloudwatch_log_group.application.name
}

output "container_image" {
  description = "Exact immutable ECR image reference registered in the task definition."
  value       = local.container_image
}
