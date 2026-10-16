variable "name_prefix" {
  description = "Environment-qualified prefix used for ECS, IAM, and log resource names."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 45 && can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain lowercase letters, numbers, or hyphens and be at most 45 characters."
  }
}

variable "aws_region" {
  description = "AWS region written into the awslogs container configuration."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must look like a valid AWS region such as us-east-1."
  }
}

variable "ecr_repository_url" {
  description = "Private ECR repository URL without an image tag."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com([./][a-z0-9._/-]+)$", var.ecr_repository_url))
    error_message = "ecr_repository_url must be a private ECR repository URL without a tag."
  }
}

variable "ecr_repository_arn" {
  description = "ARN of the one ECR repository from which the execution role may pull."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:ecr:[^:]+:[0-9]{12}:repository/.+$", var.ecr_repository_arn))
    error_message = "ecr_repository_arn must be an ECR repository ARN."
  }
}

variable "image_tag" {
  description = "Full immutable Git commit SHA already pushed to ECR."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.image_tag))
    error_message = "image_tag must be a full 40-character lowercase Git SHA; latest is not allowed."
  }
}

variable "private_subnet_ids" {
  description = "Private application subnets in at least two Availability Zones."
  type        = list(string)

  validation {
    condition = (
      length(var.private_subnet_ids) >= 2 &&
      length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids) &&
      alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[a-zA-Z0-9]+$", id))])
    )
    error_message = "private_subnet_ids must contain at least two distinct AWS subnet IDs."
  }
}

variable "ecs_security_group_id" {
  description = "Security group that accepts application traffic only from the ALB security group."
  type        = string

  validation {
    condition     = can(regex("^sg-[a-zA-Z0-9]+$", var.ecs_security_group_id))
    error_message = "ecs_security_group_id must look like an AWS security group ID."
  }
}

variable "database_host" {
  description = "Private RDS hostname passed to the application as DB_HOST."
  type        = string

  validation {
    condition     = length(trimspace(var.database_host)) > 0 && !strcontains(var.database_host, ":")
    error_message = "database_host must be a non-empty hostname without a port."
  }
}

variable "database_port" {
  description = "PostgreSQL port passed to the application as DB_PORT."
  type        = number
  default     = 5432

  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "database_port must be between 1 and 65535."
  }
}

variable "database_name" {
  description = "PostgreSQL database name passed to the application as DB_NAME."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,62}$", var.database_name))
    error_message = "database_name must begin with a letter and contain 1-63 alphanumeric characters."
  }
}

variable "database_credentials_secret_arn" {
  description = "Secrets Manager ARN containing username and password JSON keys."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.database_credentials_secret_arn))
    error_message = "database_credentials_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "container_port" {
  description = "HTTP port exposed by the API container."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units; this module supports the application-oriented sizes up to 1 vCPU."
  type        = number

  validation {
    condition     = contains([256, 512, 1024], var.task_cpu)
    error_message = "task_cpu must be one of 256, 512, or 1024 CPU units."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB; compatibility with task_cpu is enforced by the task definition."
  type        = number

  validation {
    condition     = var.task_memory >= 512 && floor(var.task_memory) == var.task_memory
    error_message = "task_memory must be an integer of at least 512 MiB."
  }
}

variable "desired_count" {
  description = "Number of task replicas the ECS service continuously maintains."
  type        = number

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 20 && floor(var.desired_count) == var.desired_count
    error_message = "desired_count must be an integer between 1 and 20."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percentage retained during an ECS rolling deployment."
  type        = number
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "deployment_minimum_healthy_percent must be between 0 and 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of desired tasks allowed during an ECS rolling deployment."
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 200
    error_message = "deployment_maximum_percent must be between 100 and 200."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for application stdout and stderr."
  type        = number

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "tags" {
  description = "Additional tags applied to ECS, IAM, and CloudWatch resources."
  type        = map(string)
  default     = {}
}
