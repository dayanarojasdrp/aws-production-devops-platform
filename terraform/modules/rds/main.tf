resource "random_password" "database" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"

  keepers = {
    credentials_version = tostring(var.credentials_version)
  }
}

resource "aws_secretsmanager_secret" "database_credentials" {
  name                    = "${var.name_prefix}/database-credentials"
  description             = "PostgreSQL credentials for ${var.name_prefix}"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-credentials"
  })
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Private database subnets for ${var.name_prefix}"
  subnet_ids  = var.private_db_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  port     = var.port

  password_wo         = random_password.database.result
  password_wo_version = var.credentials_version

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false
  network_type           = "IPV4"
  multi_az               = var.multi_az

  backup_retention_period  = var.backup_retention_days
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.delete_automated_backups

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-postgres-final-snapshot"

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
    Tier = "database"
  })
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id

  secret_string_wo = jsonencode({
    username = var.master_username
    password = random_password.database.result
  })
  secret_string_wo_version = var.credentials_version
}
