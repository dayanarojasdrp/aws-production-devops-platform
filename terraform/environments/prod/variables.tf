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

variable "tags" {
  description = "Additional tags applied to production resources."
  type        = map(string)
  default = {
    Owner = "dayanarojasdrp"
  }
}
