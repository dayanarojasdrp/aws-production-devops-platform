locals {
  container_name  = "api"
  container_image = "${var.ecr_repository_url}:${var.image_tag}"

  valid_fargate_sizes = {
    "256"  = [512, 1024, 2048]
    "512"  = [1024, 2048, 3072, 4096]
    "1024" = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
  }

  container_definitions = [
    {
      name                   = local.container_name
      image                  = local.container_image
      essential              = true
      readonlyRootFilesystem = true
      user                   = "65532"

      portMappings = [
        {
          name          = "http"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "HTTP_PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DB_HOST"
          value = var.database_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "DB_NAME"
          value = var.database_name
        },
        {
          name  = "DB_SSLMODE"
          value = "require"
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${var.database_credentials_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.database_credentials_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.application.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = local.container_name
        }
      }
    }
  ]
}

resource "aws_ecs_cluster" "this" {
  name = var.name_prefix

  tags = merge(var.tags, {
    Name = var.name_prefix
    Tier = "application"
  })
}

resource "aws_ecs_task_definition" "application" {
  family                   = "${var.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions    = jsonencode(local.container_definitions)
  skip_destroy             = true

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  lifecycle {
    precondition {
      condition     = contains(local.valid_fargate_sizes[tostring(var.task_cpu)], var.task_memory)
      error_message = "task_memory is not compatible with task_cpu for AWS Fargate."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api"
    Tier = "application"
  })
}

resource "aws_ecs_service" "application" {
  name                               = "${var.name_prefix}-api"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.application.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  scheduling_strategy                = "REPLICA"
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  availability_zone_rebalancing      = "ENABLED"
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  propagate_tags                     = "SERVICE"
  wait_for_steady_state              = true
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  lifecycle {
    # Application CD owns the active revision after the service is created.
    # Terraform still creates the configuration baseline consumed by CD.
    ignore_changes = [task_definition]

    precondition {
      condition     = var.deployment_minimum_healthy_percent <= var.deployment_maximum_percent
      error_message = "deployment_minimum_healthy_percent cannot exceed deployment_maximum_percent."
    }
  }

  depends_on = [
    aws_iam_role_policy.execution_ecr,
    aws_iam_role_policy.execution_logs,
    aws_iam_role_policy.execution_secret,
  ]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api"
    Tier = "application"
  })
}

resource "aws_appautoscaling_target" "service" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.application.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_target_tracking" {
  name               = "${aws_ecs_service.application.name}-cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
