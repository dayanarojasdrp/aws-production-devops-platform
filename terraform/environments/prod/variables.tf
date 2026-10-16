variable "aws_region" {
  description = "AWS region for the production environment."
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
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "The production root module requires environment = \"prod\"."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the production VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones used by the production environment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public ALB subnets."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private ECS application subnets."
  type        = list(string)
  default     = ["10.1.11.0/24", "10.1.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for isolated RDS database subnets."
  type        = list(string)
  default     = ["10.1.21.0/24", "10.1.22.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway when true; production defaults to one per AZ."
  type        = bool
  default     = false
}

variable "alb_ingress_ipv4_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the production ALB on HTTP and HTTPS."
  type        = set(string)
  default     = ["0.0.0.0/0"]
}

variable "application_port" {
  description = "Port used from the production ALB to ECS tasks."
  type        = number
  default     = 8080
}

variable "postgres_port" {
  description = "Port used from production ECS tasks to PostgreSQL."
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Initial PostgreSQL database name for production."
  type        = string
  default     = "platform"
}

variable "database_master_username" {
  description = "PostgreSQL master username stored in Secrets Manager."
  type        = string
  default     = "appuser"
}

variable "database_engine_version" {
  description = "PostgreSQL major engine version for production."
  type        = string
  default     = "16"
}

variable "database_instance_class" {
  description = "Availability-oriented RDS instance class for production design."
  type        = string
  default     = "db.t4g.small"
}

variable "database_allocated_storage" {
  description = "Initial production database storage in GiB."
  type        = number
  default     = 50
}

variable "database_max_allocated_storage" {
  description = "Production storage autoscaling limit in GiB."
  type        = number
  default     = 200
}

variable "database_multi_az" {
  description = "Enable Multi-AZ for production."
  type        = bool
  default     = true
}

variable "database_backup_retention_days" {
  description = "Production automated backup retention in days."
  type        = number
  default     = 7
}

variable "database_deletion_protection" {
  description = "Enable deletion protection for the production database."
  type        = bool
  default     = true
}

variable "database_skip_final_snapshot" {
  description = "Allow production deletion without a final snapshot."
  type        = bool
  default     = false
}

variable "database_delete_automated_backups" {
  description = "Delete automated backups with the production database."
  type        = bool
  default     = false
}

variable "database_apply_immediately" {
  description = "Apply production database changes immediately."
  type        = bool
  default     = false
}

variable "database_secret_recovery_window_days" {
  description = "Recovery window for production secret deletion."
  type        = number
  default     = 30
}

variable "database_credentials_version" {
  description = "Increment deliberately to rotate production database credentials."
  type        = number
  default     = 1
}

variable "ecr_max_image_count" {
  description = "Maximum number of application images retained in the production ECR repository."
  type        = number
  default     = 50

  validation {
    condition     = var.ecr_max_image_count >= 2 && var.ecr_max_image_count <= 1000 && floor(var.ecr_max_image_count) == var.ecr_max_image_count
    error_message = "ecr_max_image_count must be an integer between 2 and 1000."
  }
}

variable "ecr_force_delete" {
  description = "Allow production repository deletion while images remain."
  type        = bool
  default     = false

  validation {
    condition     = var.ecr_force_delete == false
    error_message = "Production must keep ecr_force_delete disabled."
  }
}

variable "ecs_image_tag" {
  description = "Full Git commit SHA of the production API image already pushed to ECR."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.ecs_image_tag))
    error_message = "ecs_image_tag must be a full 40-character lowercase Git SHA."
  }
}

variable "ecs_task_cpu" {
  description = "Production Fargate task CPU units."
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024], var.ecs_task_cpu)
    error_message = "Production ecs_task_cpu must be 512 or 1024."
  }
}

variable "ecs_task_memory" {
  description = "Production Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Number of production API tasks maintained by the ECS service."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 2 && var.ecs_desired_count <= 20 && floor(var.ecs_desired_count) == var.ecs_desired_count
    error_message = "Production ecs_desired_count must be an integer between 2 and 20."
  }
}

variable "ecs_log_retention_days" {
  description = "Production application log retention in CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([30, 60, 90, 120, 150, 180, 365], var.ecs_log_retention_days)
    error_message = "Production ecs_log_retention_days must be one of 30, 60, 90, 120, 150, 180, or 365."
  }
}

variable "tags" {
  description = "Additional tags applied to production resources."
  type        = map(string)
  default = {
    Owner = "dayanarojasdrp"
  }
}
