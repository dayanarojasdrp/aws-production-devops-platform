variable "name_prefix" {
  description = "Prefix used in security group names and Name tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC that contains the ALB, ECS, and RDS tiers."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-zA-Z0-9]+$", var.vpc_id))
    error_message = "vpc_id must look like an AWS VPC ID."
  }
}

variable "alb_ingress_ipv4_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the public ALB on ports 80 and 443."
  type        = set(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.alb_ingress_ipv4_cidrs) > 0 && alltrue([for cidr in var.alb_ingress_ipv4_cidrs : can(cidrnetmask(cidr))])
    error_message = "alb_ingress_ipv4_cidrs must contain at least one valid IPv4 CIDR block."
  }
}

variable "application_port" {
  description = "TCP port exposed by the application tasks to the ALB."
  type        = number
  default     = 8080

  validation {
    condition     = var.application_port >= 1 && var.application_port <= 65535
    error_message = "application_port must be between 1 and 65535."
  }
}

variable "postgres_port" {
  description = "TCP port exposed by PostgreSQL to the application tasks."
  type        = number
  default     = 5432

  validation {
    condition     = var.postgres_port >= 1 && var.postgres_port <= 65535
    error_message = "postgres_port must be between 1 and 65535."
  }
}

variable "tags" {
  description = "Additional tags applied to all security groups."
  type        = map(string)
  default     = {}
}
