variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Stable project identifier used to name and tag bootstrap resources."
  type        = string
  default     = "aws-production-devops-platform"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid globally unique S3 bucket name between 3 and 63 characters."
  }
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name allowed to assume the IAM role."
  type        = string
}

variable "github_branch" {
  description = "Only workflows running from this branch may assume the IAM role."
  type        = string
  default     = "main"
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID for repositories using the post-July-2026 OIDC subject format. Set together with github_repository_id."
  type        = string
  default     = null
  nullable    = true
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID for repositories using the post-July-2026 OIDC subject format. Set together with github_owner_id."
  type        = string
  default     = null
  nullable    = true
}

variable "github_deployment_environments" {
  description = "GitHub Environment names trusted by the development and production deployment roles."
  type = object({
    development = string
    production  = string
  })
  default = {
    development = "development"
    production  = "production"
  }

  validation {
    condition = (
      var.github_deployment_environments.development != var.github_deployment_environments.production &&
      alltrue([
        for name in [
          var.github_deployment_environments.development,
          var.github_deployment_environments.production,
        ] :
        can(regex("^[A-Za-z0-9._-]+$", name))
      ])
    )
    error_message = "GitHub deployment environment names must be distinct and contain only letters, numbers, dots, underscores, or hyphens."
  }
}

variable "tags" {
  description = "Additional tags applied to bootstrap resources."
  type        = map(string)
  default = {
    Environment = "shared"
  }
}
