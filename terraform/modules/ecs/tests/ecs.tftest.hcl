mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock-ecs-role"
      id  = "mock-ecs-role"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/mock/api"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/mock"
      id  = "arn:aws:ecs:us-east-1:123456789012:cluster/mock"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/mock:1"
    }
  }
}

variables {
  name_prefix                     = "test-platform-dev"
  aws_region                      = "us-east-1"
  ecr_repository_url              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test-platform-dev-api"
  ecr_repository_arn              = "arn:aws:ecr:us-east-1:123456789012:repository/test-platform-dev-api"
  image_tag                       = "0123456789abcdef0123456789abcdef01234567"
  private_subnet_ids              = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_security_group_id           = "sg-0123456789abcdef0"
  target_group_arn                = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-platform-dev-api/0123456789abcdef"
  database_host                   = "test-platform-dev.cluster-example.us-east-1.rds.amazonaws.com"
  database_port                   = 5432
  database_name                   = "platform"
  database_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-platform-dev/database-credentials-AbCdEf"
  task_cpu                        = 256
  task_memory                     = 512
  desired_count                   = 1
  log_retention_days              = 7
}

run "development_service" {
  command = apply

  assert {
    condition     = aws_ecs_cluster.this.name == "test-platform-dev"
    error_message = "The ECS cluster must use the environment-qualified platform name."
  }

  assert {
    condition = (
      aws_ecs_task_definition.application.requires_compatibilities == toset(["FARGATE"]) &&
      aws_ecs_task_definition.application.network_mode == "awsvpc" &&
      aws_ecs_task_definition.application.cpu == "256" &&
      aws_ecs_task_definition.application.memory == "512" &&
      aws_ecs_task_definition.application.skip_destroy == true
    )
    error_message = "The task definition must use Fargate, awsvpc, the development size, and retained revisions."
  }

  assert {
    condition = (
      one(aws_ecs_task_definition.application.runtime_platform).cpu_architecture == "X86_64" &&
      one(aws_ecs_task_definition.application.runtime_platform).operating_system_family == "LINUX"
    )
    error_message = "The task runtime must match the linux/amd64 image built by CI."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].image == "123456789012.dkr.ecr.us-east-1.amazonaws.com/test-platform-dev-api:0123456789abcdef0123456789abcdef01234567" &&
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].portMappings[0].containerPort == 8080 &&
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].readonlyRootFilesystem == true &&
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].user == "65532"
    )
    error_message = "The API container must use the exact SHA image and hardened runtime settings."
  }

  assert {
    condition = (
      { for item in jsondecode(aws_ecs_task_definition.application.container_definitions)[0].environment : item.name => item.value } == {
        HTTP_PORT  = "8080"
        DB_HOST    = "test-platform-dev.cluster-example.us-east-1.rds.amazonaws.com"
        DB_PORT    = "5432"
        DB_NAME    = "platform"
        DB_SSLMODE = "require"
      }
    )
    error_message = "Only non-secret application configuration may appear in plaintext environment values."
  }

  assert {
    condition = (
      { for item in jsondecode(aws_ecs_task_definition.application.container_definitions)[0].secrets : item.name => item.valueFrom } == {
        DB_USER     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-platform-dev/database-credentials-AbCdEf:username::"
        DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-platform-dev/database-credentials-AbCdEf:password::"
      }
    )
    error_message = "Database credentials must be injected from the exact Secrets Manager JSON keys."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].logConfiguration.logDriver == "awslogs" &&
      jsondecode(aws_ecs_task_definition.application.container_definitions)[0].logConfiguration.options.awslogs-group == "/ecs/test-platform-dev/api" &&
      aws_cloudwatch_log_group.application.retention_in_days == 7
    )
    error_message = "Application stdout and stderr must use the environment log group and retention."
  }

  assert {
    condition = (
      aws_ecs_service.application.desired_count == 1 &&
      aws_ecs_service.application.launch_type == "FARGATE" &&
      aws_ecs_service.application.platform_version == "1.4.0" &&
      aws_ecs_service.application.availability_zone_rebalancing == "ENABLED" &&
      aws_ecs_service.application.health_check_grace_period_seconds == 30 &&
      aws_ecs_service.application.wait_for_steady_state == true &&
      aws_ecs_service.application.deployment_circuit_breaker[0].enable == true &&
      aws_ecs_service.application.deployment_circuit_breaker[0].rollback == true
    )
    error_message = "The service must continuously maintain the development task on Fargate and enable automatic rollback on failed deployments."
  }

  assert {
    condition = (
      one(aws_ecs_service.application.load_balancer).target_group_arn == var.target_group_arn &&
      one(aws_ecs_service.application.load_balancer).container_name == "api" &&
      one(aws_ecs_service.application.load_balancer).container_port == 8080
    )
    error_message = "The service must register API task IPs and port 8080 with the supplied target group."
  }

  assert {
    condition = (
      aws_appautoscaling_target.service.min_capacity == 2 &&
      aws_appautoscaling_target.service.max_capacity == 6 &&
      aws_appautoscaling_policy.cpu_target_tracking.policy_type == "TargetTrackingScaling" &&
      aws_appautoscaling_policy.cpu_target_tracking.target_tracking_scaling_policy_configuration[0].target_value == 60 &&
      aws_appautoscaling_policy.cpu_target_tracking.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageCPUUtilization"
    )
    error_message = "The ECS service must enable CPU-based target tracking auto scaling with a 2-6 replica range."
  }

  assert {
    condition = (
      one(aws_ecs_service.application.network_configuration).assign_public_ip == false &&
      one(aws_ecs_service.application.network_configuration).subnets == toset(var.private_subnet_ids) &&
      one(aws_ecs_service.application.network_configuration).security_groups == toset([var.ecs_security_group_id])
    )
    error_message = "Fargate tasks must use only private application subnets and the ECS security group."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.execution.assume_role_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com" &&
      jsondecode(aws_iam_role.task.assume_role_policy).Statement[0].Principal.Service == "ecs-tasks.amazonaws.com"
    )
    error_message = "Both ECS identities must trust only the ECS tasks service principal."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.execution_secret.policy).Statement[0].Resource == var.database_credentials_secret_arn &&
      jsondecode(aws_iam_role_policy.execution_logs.policy).Statement[0].Resource == "${aws_cloudwatch_log_group.application.arn}:*" &&
      jsondecode(aws_iam_role_policy.execution_ecr.policy).Statement[1].Resource == var.ecr_repository_arn
    )
    error_message = "Execution-role permissions must be scoped to the exact secret, log group, and ECR repository."
  }
}

run "production_service" {
  command = apply

  variables {
    name_prefix                     = "test-platform-prod"
    ecr_repository_url              = "123456789012.dkr.ecr.us-east-1.amazonaws.com/test-platform-prod-api"
    ecr_repository_arn              = "arn:aws:ecr:us-east-1:123456789012:repository/test-platform-prod-api"
    database_host                   = "test-platform-prod.cluster-example.us-east-1.rds.amazonaws.com"
    database_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-platform-prod/database-credentials-AbCdEf"
    target_group_arn                = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-platform-prod-api/0123456789abcdef"
    task_cpu                        = 512
    task_memory                     = 1024
    desired_count                   = 2
    log_retention_days              = 30
  }

  assert {
    condition = (
      aws_ecs_task_definition.application.cpu == "512" &&
      aws_ecs_task_definition.application.memory == "1024" &&
      aws_ecs_service.application.desired_count == 2 &&
      aws_cloudwatch_log_group.application.retention_in_days == 30
    )
    error_message = "Production must use the larger task size, two replicas, and longer log retention."
  }
}
