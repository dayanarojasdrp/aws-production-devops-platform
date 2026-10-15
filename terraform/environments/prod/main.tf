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
