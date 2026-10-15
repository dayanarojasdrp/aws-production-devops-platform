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

variable "postgres_port" {
  description = "Port used from development ECS tasks to PostgreSQL."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Additional tags applied to development resources."
  type        = map(string)
  default = {
    Owner = "dayanarojasdrp"
  }
}
