locals {
  ecs_tasks_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcsTasksAssumeRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-execution"
  description        = "Allows ECS to pull the API image, inject its database secret, and publish logs."
  assume_role_policy = local.ecs_tasks_assume_role_policy

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-execution"
  })
}

resource "aws_iam_role_policy" "execution_ecr" {
  name = "pull-api-image"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetEcrAuthorizationToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PullFromApplicationRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "execution_logs" {
  name = "write-application-logs"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteApplicationLogStreams"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.application.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "execution_secret" {
  name = "read-database-credentials"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDatabaseCredentials"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_credentials_secret_arn
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  description        = "Identity exposed to the API container; intentionally has no AWS API permissions."
  assume_role_policy = local.ecs_tasks_assume_role_policy

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task"
  })
}
