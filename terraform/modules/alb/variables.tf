variable "name_prefix" {
  description = "Environment-qualified prefix used for ALB resource names and tags."
  type        = string

  validation {
    condition     = length(var.name_prefix) >= 2 && length(var.name_prefix) <= 45 && can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix must be 2-45 characters, use lowercase letters, numbers, or hyphens, and not begin or end with a hyphen."
  }
}

variable "vpc_id" {
  description = "VPC containing both the public ALB subnets and private ECS targets."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-zA-Z0-9]+$", var.vpc_id))
    error_message = "vpc_id must look like an AWS VPC ID."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs spanning at least two Availability Zones."
  type        = list(string)

  validation {
    condition = (
      length(var.public_subnet_ids) >= 2 &&
      length(distinct(var.public_subnet_ids)) == length(var.public_subnet_ids) &&
      alltrue([for id in var.public_subnet_ids : can(regex("^subnet-[a-zA-Z0-9]+$", id))])
    )
    error_message = "public_subnet_ids must contain at least two distinct AWS subnet IDs."
  }
}

variable "alb_security_group_id" {
  description = "Security group accepting public HTTP and future HTTPS traffic for the ALB."
  type        = string

  validation {
    condition     = can(regex("^sg-[a-zA-Z0-9]+$", var.alb_security_group_id))
    error_message = "alb_security_group_id must look like an AWS security group ID."
  }
}

variable "container_port" {
  description = "Private ECS container port used by the target group."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535 && floor(var.container_port) == var.container_port
    error_message = "container_port must be an integer between 1 and 65535."
  }
}

variable "health_check_path" {
  description = "Lightweight application liveness endpoint evaluated by the target group."
  type        = string
  default     = "/healthz"

  validation {
    condition     = length(var.health_check_path) <= 1024 && startswith(var.health_check_path, "/") && !strcontains(var.health_check_path, " ")
    error_message = "health_check_path must begin with /, contain no spaces, and be at most 1024 characters."
  }
}

variable "health_check_interval_seconds" {
  description = "Seconds between target health checks."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval_seconds >= 5 && var.health_check_interval_seconds <= 300 && floor(var.health_check_interval_seconds) == var.health_check_interval_seconds
    error_message = "health_check_interval_seconds must be an integer between 5 and 300."
  }
}

variable "health_check_timeout_seconds" {
  description = "Seconds before one health check is considered failed."
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout_seconds >= 2 && var.health_check_timeout_seconds <= 120 && floor(var.health_check_timeout_seconds) == var.health_check_timeout_seconds
    error_message = "health_check_timeout_seconds must be an integer between 2 and 120."
  }
}

variable "healthy_threshold" {
  description = "Consecutive successful checks required to return an unhealthy target to service."
  type        = number
  default     = 2

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10 && floor(var.healthy_threshold) == var.healthy_threshold
    error_message = "healthy_threshold must be an integer between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks required to mark a target unhealthy."
  type        = number
  default     = 2

  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10 && floor(var.unhealthy_threshold) == var.unhealthy_threshold
    error_message = "unhealthy_threshold must be an integer between 2 and 10."
  }
}

variable "deregistration_delay_seconds" {
  description = "Connection-draining time allowed for in-flight requests during target removal."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay_seconds >= 0 && var.deregistration_delay_seconds <= 3600 && floor(var.deregistration_delay_seconds) == var.deregistration_delay_seconds
    error_message = "deregistration_delay_seconds must be an integer between 0 and 3600."
  }
}

variable "idle_timeout_seconds" {
  description = "ALB connection idle timeout."
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout_seconds >= 1 && var.idle_timeout_seconds <= 4000 && floor(var.idle_timeout_seconds) == var.idle_timeout_seconds
    error_message = "idle_timeout_seconds must be an integer between 1 and 4000."
  }
}

variable "enable_deletion_protection" {
  description = "Protect the load balancer from accidental deletion."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
