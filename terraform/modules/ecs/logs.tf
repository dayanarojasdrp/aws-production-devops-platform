resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.name_prefix}/api"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-logs"
    Tier = "application"
  })
}
