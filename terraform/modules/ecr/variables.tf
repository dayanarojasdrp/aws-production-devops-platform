variable "repository_name" {
  description = "Name of the private ECR repository that stores application images."
  type        = string

  validation {
    condition = (
      length(var.repository_name) >= 2 &&
      length(var.repository_name) <= 256 &&
      can(regex("^[a-z0-9]+([._/-][a-z0-9]+)*$", var.repository_name))
    )
    error_message = "repository_name must be 2-256 characters and use valid lowercase ECR repository-name segments."
  }
}

variable "max_image_count" {
  description = "Maximum number of images retained before ECR expires the oldest images."
  type        = number

  validation {
    condition     = var.max_image_count >= 2 && var.max_image_count <= 1000 && floor(var.max_image_count) == var.max_image_count
    error_message = "max_image_count must be an integer between 2 and 1000 so at least one rollback candidate can be retained."
  }
}

variable "force_delete" {
  description = "Allow Terraform to delete the repository while it still contains images."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to the ECR repository."
  type        = map(string)
  default     = {}
}
