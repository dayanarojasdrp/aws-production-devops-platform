variable "aws_region" {
  description = "AWS region for the development environment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Stable project identifier used in names and tags."
  type        = string
  default     = "aws-production-devops-platform"
}

variable "environment" {
  description = "Environment name used in names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "The development root module requires environment = \"dev\"."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the development VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones used by the development environment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public ALB subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private ECS application subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for isolated RDS database subnets."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway to reduce development cost."
  type        = bool
  default     = true
}

variable "alb_ingress_ipv4_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the development ALB on HTTP and HTTPS."
  type        = set(string)
  default     = ["0.0.0.0/0"]
}

variable "application_port" {
  description = "Port used from the development ALB to ECS tasks."
  type        = number
  default     = 8080
}

variable "alb_deregistration_delay_seconds" {
  description = "Development connection-draining period for targets removed from the ALB."
  type        = number
  default     = 30

  validation {
    condition     = var.alb_deregistration_delay_seconds >= 0 && var.alb_deregistration_delay_seconds <= 3600 && floor(var.alb_deregistration_delay_seconds) == var.alb_deregistration_delay_seconds
    error_message = "alb_deregistration_delay_seconds must be an integer between 0 and 3600."
  }
}

variable "alb_deletion_protection" {
  description = "Protect the development ALB from accidental deletion."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Create development DNS, ACM validation, HTTPS, and the HTTP redirect."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_https || (var.application_domain_name != null && var.route53_zone_id != null)
    error_message = "application_domain_name and route53_zone_id are required when enable_https is true."
  }
}

variable "application_domain_name" {
  description = "Development API FQDN, normally a distinct hostname such as api-dev.example.com."
  type        = string
  default     = null
  nullable    = true
}

variable "route53_zone_id" {
  description = "Existing public Route 53 hosted zone ID authoritative for the development API hostname."
  type        = string
  default     = null
  nullable    = true
}

variable "tls_security_policy" {
  description = "TLS policy for the development ALB HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "postgres_port" {
  description = "Port used from development ECS tasks to PostgreSQL."
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Initial PostgreSQL database name for development."
  type        = string
  default     = "platform"
}

variable "database_master_username" {
  description = "PostgreSQL master username stored in Secrets Manager."
  type        = string
  default     = "appuser"
}

variable "database_engine_version" {
  description = "PostgreSQL major engine version for development."
  type        = string
  default     = "16"
}

variable "database_instance_class" {
  description = "Cost-oriented RDS instance class for development."
  type        = string
  default     = "db.t4g.micro"
}

variable "database_allocated_storage" {
  description = "Initial development database storage in GiB."
  type        = number
  default     = 20
}

variable "database_max_allocated_storage" {
  description = "Development storage autoscaling limit in GiB."
  type        = number
  default     = 50
}

variable "database_multi_az" {
  description = "Enable Multi-AZ for development."
  type        = bool
  default     = false
}

variable "database_backup_retention_days" {
  description = "Development automated backup retention in days."
  type        = number
  default     = 1
}

variable "database_deletion_protection" {
  description = "Enable deletion protection for the development database."
  type        = bool
  default     = false
}

variable "database_skip_final_snapshot" {
  description = "Allow development deletion without a final snapshot."
  type        = bool
  default     = true
}

variable "database_delete_automated_backups" {
  description = "Delete automated backups with the development database."
  type        = bool
  default     = true
}

variable "database_apply_immediately" {
  description = "Apply development database changes immediately."
  type        = bool
  default     = true
}

variable "database_secret_recovery_window_days" {
  description = "Recovery window for development secret deletion."
  type        = number
  default     = 0
}

variable "database_credentials_version" {
  description = "Increment deliberately to rotate development database credentials."
  type        = number
  default     = 1
}

variable "ecr_max_image_count" {
  description = "Maximum number of application images retained in the development ECR repository."
  type        = number
  default     = 20

  validation {
    condition     = var.ecr_max_image_count >= 2 && var.ecr_max_image_count <= 1000 && floor(var.ecr_max_image_count) == var.ecr_max_image_count
    error_message = "ecr_max_image_count must be an integer between 2 and 1000."
  }
}

variable "ecr_force_delete" {
  description = "Allow development repository deletion while test images remain."
  type        = bool
  default     = true
}

variable "ecs_image_tag" {
  description = "Full Git commit SHA of the development API image already pushed to ECR."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.ecs_image_tag))
    error_message = "ecs_image_tag must be a full 40-character lowercase Git SHA."
  }
}

variable "ecs_task_cpu" {
  description = "Development Fargate task CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024], var.ecs_task_cpu)
    error_message = "ecs_task_cpu must be one of 256, 512, or 1024."
  }
}

variable "ecs_task_memory" {
  description = "Development Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Number of development API tasks maintained by the ECS service."
  type        = number
  default     = 1

  validation {
    condition     = var.ecs_desired_count >= 1 && var.ecs_desired_count <= 10 && floor(var.ecs_desired_count) == var.ecs_desired_count
    error_message = "ecs_desired_count must be an integer between 1 and 10."
  }
}

variable "ecs_health_check_grace_period_seconds" {
  description = "Development startup grace period before ECS reacts to ALB health failures."
  type        = number
  default     = 30

  validation {
    condition     = var.ecs_health_check_grace_period_seconds >= 0 && var.ecs_health_check_grace_period_seconds <= 300 && floor(var.ecs_health_check_grace_period_seconds) == var.ecs_health_check_grace_period_seconds
    error_message = "ecs_health_check_grace_period_seconds must be an integer between 0 and 300."
  }
}

variable "ecs_log_retention_days" {
  description = "Development application log retention in CloudWatch Logs."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.ecs_log_retention_days)
    error_message = "ecs_log_retention_days must be one of 1, 3, 5, 7, 14, or 30 for development."
  }
}

variable "tags" {
  description = "Additional tags applied to development resources."
  type        = map(string)
  default = {
    Owner = "dayanarojasdrp"
  }
}
