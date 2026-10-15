mock_provider "aws" {}

variables {
  name_prefix = "test-platform-dev"
  vpc_id      = "vpc-0123456789abcdef0"
}

run "security_group_chaining" {
  command = apply

  assert {
    condition     = aws_security_group.alb.name == "test-platform-dev-alb-sg"
    error_message = "The ALB security group name must identify its tier."
  }

  assert {
    condition     = aws_security_group.ecs.name == "test-platform-dev-ecs-sg"
    error_message = "The ECS security group name must identify its tier."
  }

  assert {
    condition     = aws_security_group.rds.name == "test-platform-dev-rds-sg"
    error_message = "The RDS security group name must identify its tier."
  }

  assert {
    condition = alltrue([
      for rule in aws_vpc_security_group_ingress_rule.alb_http :
      rule.cidr_ipv4 == "0.0.0.0/0" && rule.from_port == 80 && rule.to_port == 80
    ])
    error_message = "The ALB must accept public HTTP only on port 80."
  }

  assert {
    condition = alltrue([
      for rule in aws_vpc_security_group_ingress_rule.alb_https :
      rule.cidr_ipv4 == "0.0.0.0/0" && rule.from_port == 443 && rule.to_port == 443
    ])
    error_message = "The ALB must accept public HTTPS only on port 443."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.ecs_from_alb.referenced_security_group_id == aws_security_group.alb.id &&
      aws_vpc_security_group_ingress_rule.ecs_from_alb.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.ecs_from_alb.from_port == 8080
    )
    error_message = "ECS must accept port 8080 only from the ALB security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.rds_from_ecs.referenced_security_group_id == aws_security_group.ecs.id &&
      aws_vpc_security_group_ingress_rule.rds_from_ecs.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.rds_from_ecs.from_port == 5432
    )
    error_message = "RDS must accept port 5432 only from the ECS security group."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_egress_rule.alb.ip_protocol == "-1",
      aws_vpc_security_group_egress_rule.ecs.ip_protocol == "-1",
      aws_vpc_security_group_egress_rule.rds.ip_protocol == "-1",
    ])
    error_message = "All three security groups must declare the temporary all-egress policy explicitly."
  }
}
