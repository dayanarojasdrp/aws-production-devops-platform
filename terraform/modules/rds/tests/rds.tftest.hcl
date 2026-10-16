mock_provider "aws" {}

variables {
  name_prefix                 = "test-platform-dev"
  private_db_subnet_ids       = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  rds_security_group_id       = "sg-0123456789abcdef0"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 50
  multi_az                    = false
  backup_retention_days       = 1
  deletion_protection         = false
  skip_final_snapshot         = true
  delete_automated_backups    = true
  apply_immediately           = true
  secret_recovery_window_days = 0
}

run "development_database" {
  command = apply

  assert {
    condition     = aws_db_subnet_group.this.subnet_ids == toset(var.private_db_subnet_ids)
    error_message = "The DB subnet group must contain every private database subnet."
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "RDS must never be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "RDS storage encryption must remain enabled."
  }

  assert {
    condition     = aws_db_instance.this.vpc_security_group_ids == toset([var.rds_security_group_id])
    error_message = "RDS must use only the chained database security group."
  }

  assert {
    condition = (
      aws_db_instance.this.multi_az == false &&
      aws_db_instance.this.backup_retention_period == 1 &&
      aws_db_instance.this.deletion_protection == false &&
      aws_db_instance.this.skip_final_snapshot == true
    )
    error_message = "Development must use the lower-cost database lifecycle settings."
  }

  assert {
    condition     = aws_secretsmanager_secret.database_credentials.recovery_window_in_days == 0
    error_message = "Development secrets must support immediate cleanup."
  }

  assert {
    condition = (
      random_password.database.keepers.credentials_version == "1" &&
      aws_db_instance.this.password_wo_version == 1 &&
      aws_secretsmanager_secret_version.database_credentials.secret_string_wo_version == 1
    )
    error_message = "One credential version must coordinate password generation, RDS, and Secrets Manager."
  }
}

run "production_database" {
  command = apply

  variables {
    name_prefix                 = "test-platform-prod"
    instance_class              = "db.t4g.small"
    allocated_storage           = 50
    max_allocated_storage       = 200
    multi_az                    = true
    backup_retention_days       = 7
    deletion_protection         = true
    skip_final_snapshot         = false
    delete_automated_backups    = false
    apply_immediately           = false
    secret_recovery_window_days = 30
  }

  assert {
    condition = (
      aws_db_instance.this.multi_az == true &&
      aws_db_instance.this.backup_retention_period == 7 &&
      aws_db_instance.this.deletion_protection == true &&
      aws_db_instance.this.skip_final_snapshot == false
    )
    error_message = "Production must enable stronger availability, recovery, and deletion safeguards."
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "test-platform-prod-postgres-final-snapshot"
    error_message = "Production deletion must require a final snapshot identifier."
  }

  assert {
    condition     = aws_secretsmanager_secret.database_credentials.recovery_window_in_days == 30
    error_message = "Production secret deletion must retain a recovery window."
  }
}
