variable "name_prefix" {
  description = "Prefix used in database resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "private_db_subnet_ids" {
  description = "Private database subnet IDs spanning at least two Availability Zones."
  type        = list(string)

  validation {
    condition = (
      length(var.private_db_subnet_ids) >= 2 &&
      length(distinct(var.private_db_subnet_ids)) == length(var.private_db_subnet_ids) &&
      alltrue([for id in var.private_db_subnet_ids : can(regex("^subnet-[a-zA-Z0-9]+$", id))])
    )
    error_message = "private_db_subnet_ids must contain at least two distinct AWS subnet IDs."
  }
}

variable "rds_security_group_id" {
  description = "Security group that accepts PostgreSQL only from the ECS security group."
  type        = string

  validation {
    condition     = can(regex("^sg-[a-zA-Z0-9]+$", var.rds_security_group_id))
    error_message = "rds_security_group_id must look like an AWS security group ID."
  }
}

variable "database_name" {
  description = "Initial PostgreSQL database created with the instance."
  type        = string
  default     = "platform"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,62}$", var.database_name))
    error_message = "database_name must begin with a letter and contain 1-63 alphanumeric characters."
  }
}

variable "master_username" {
  description = "Master PostgreSQL username stored alongside the generated password in Secrets Manager."
  type        = string
  default     = "appuser"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.master_username))
    error_message = "master_username must begin with a letter and contain 1-63 letters, numbers, or underscores."
  }
}

variable "port" {
  description = "PostgreSQL listener port."
  type        = number
  default     = 5432

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "port must be between 1 and 65535."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine major or major/minor version."
  type        = string
  default     = "16"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.engine_version))
    error_message = "engine_version must be a PostgreSQL major or major/minor version such as 16 or 16.4."
  }
}

variable "instance_class" {
  description = "RDS instance class selected for the environment."
  type        = string

  validation {
    condition     = startswith(var.instance_class, "db.")
    error_message = "instance_class must be an RDS class beginning with db."
  }
}

variable "allocated_storage" {
  description = "Initial gp3 storage allocation in GiB."
  type        = number

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling limit in GiB; use 0 to disable autoscaling."
  type        = number

  validation {
    condition     = var.max_allocated_storage == 0 || var.max_allocated_storage >= ceil(var.allocated_storage * 1.1)
    error_message = "max_allocated_storage must be 0 or at least 10 percent greater than allocated_storage."
  }
}

variable "multi_az" {
  description = "Deploy a synchronous standby in another Availability Zone."
  type        = bool
}

variable "backup_retention_days" {
  description = "Number of days that RDS retains automated backups."
  type        = number

  validation {
    condition = (
      var.backup_retention_days >= 0 &&
      var.backup_retention_days <= 35 &&
      (!var.multi_az || var.backup_retention_days > 0)
    )
    error_message = "backup_retention_days must be between 0 and 35 and greater than 0 for Multi-AZ."
  }
}

variable "deletion_protection" {
  description = "Prevent accidental deletion until protection is explicitly disabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the instance is deleted."
  type        = bool

  validation {
    condition     = !var.deletion_protection || !var.skip_final_snapshot
    error_message = "A deletion-protected database must require a final snapshot."
  }
}

variable "delete_automated_backups" {
  description = "Delete automated backups when the database instance is deleted."
  type        = bool
}

variable "apply_immediately" {
  description = "Apply database modifications immediately instead of waiting for the maintenance window."
  type        = bool
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window; 0 deletes immediately and 7-30 schedules recovery."
  type        = number

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 or between 7 and 30."
  }
}

variable "credentials_version" {
  description = "Monotonic version used to trigger a controlled database credential rotation."
  type        = number
  default     = 1

  validation {
    condition     = var.credentials_version >= 1 && floor(var.credentials_version) == var.credentials_version
    error_message = "credentials_version must be a positive integer."
  }
}

variable "tags" {
  description = "Additional tags applied to database and secret resources."
  type        = map(string)
  default     = {}
}
