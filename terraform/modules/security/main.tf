resource "aws_security_group" "alb" {
  name                   = "${var.name_prefix}-alb-sg"
  description            = "Public ingress for the application load balancer"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
    Tier = "load-balancer"
  })
}

resource "aws_security_group" "ecs" {
  name                   = "${var.name_prefix}-ecs-sg"
  description            = "Application traffic from the load balancer to ECS tasks"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-sg"
    Tier = "application"
  })
}

resource "aws_security_group" "rds" {
  name                   = "${var.name_prefix}-rds-sg"
  description            = "PostgreSQL traffic from ECS tasks to RDS"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
    Tier = "database"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = var.alb_ingress_ipv4_cidrs

  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP entry point redirected to HTTPS when TLS is enabled"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = var.alb_ingress_ipv4_cidrs

  security_group_id = aws_security_group.alb.id
  description       = "Public HTTPS application entry point"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Application traffic from the ALB security group"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.application_port
  to_port                      = var.application_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL traffic from the ECS security group"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.postgres_port
  to_port                      = var.postgres_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Application and health-check traffic to ECS tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.application_port
  to_port                      = var.application_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs" {
  security_group_id = aws_security_group.ecs.id
  description       = "Egress for ECR, logs, secrets, database, and AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "rds" {
  security_group_id = aws_security_group.rds.id
  description       = "Explicit managed-service egress pending later hardening"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
