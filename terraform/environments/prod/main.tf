locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

module "networking" {
  source = "../../modules/networking"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
  tags                     = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name_prefix            = local.name_prefix
  vpc_id                 = module.networking.vpc_id
  alb_ingress_ipv4_cidrs = var.alb_ingress_ipv4_cidrs
  application_port       = var.application_port
  postgres_port          = var.postgres_port
  tags                   = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix                 = local.name_prefix
  private_db_subnet_ids       = module.networking.private_db_subnet_ids
  rds_security_group_id       = module.security.rds_security_group_id
  database_name               = var.database_name
  master_username             = var.database_master_username
  port                        = var.postgres_port
  engine_version              = var.database_engine_version
  instance_class              = var.database_instance_class
  allocated_storage           = var.database_allocated_storage
  max_allocated_storage       = var.database_max_allocated_storage
  multi_az                    = var.database_multi_az
  backup_retention_days       = var.database_backup_retention_days
  deletion_protection         = var.database_deletion_protection
  skip_final_snapshot         = var.database_skip_final_snapshot
  delete_automated_backups    = var.database_delete_automated_backups
  apply_immediately           = var.database_apply_immediately
  secret_recovery_window_days = var.database_secret_recovery_window_days
  credentials_version         = var.database_credentials_version
  tags                        = local.common_tags
}
