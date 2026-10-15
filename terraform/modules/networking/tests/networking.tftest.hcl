mock_provider "aws" {}

variables {
  name_prefix              = "test-network"
  vpc_cidr                 = "10.20.0.0/16"
  availability_zones       = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs      = ["10.20.1.0/24", "10.20.2.0/24"]
  private_app_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
  private_db_subnet_cidrs  = ["10.20.21.0/24", "10.20.22.0/24"]
}

run "single_nat_development_topology" {
  command = plan

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "The module must create two public subnets."
  }

  assert {
    condition     = length(aws_subnet.private_app) == 2
    error_message = "The module must create two private application subnets."
  }

  assert {
    condition     = length(aws_subnet.private_db) == 2
    error_message = "The module must create two isolated database subnets."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Single-NAT mode must create exactly one NAT Gateway."
  }

  assert {
    condition     = length(aws_route.private_app_egress) == 2
    error_message = "Each application subnet must have an outbound NAT route."
  }

  assert {
    condition     = alltrue([for subnet in aws_subnet.public : subnet.map_public_ip_on_launch == false])
    error_message = "Automatic public IP assignment must remain disabled."
  }
}

run "per_az_nat_production_topology" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Per-AZ mode must create exactly two NAT Gateways."
  }

  assert {
    condition     = length(aws_eip.nat) == 2
    error_message = "Per-AZ mode must allocate one Elastic IP per NAT Gateway."
  }

  assert {
    condition     = length(aws_route_table.private_db) == 2
    error_message = "The database tier must have one route table per Availability Zone."
  }

  assert {
    condition     = length(aws_route_table_association.private_db) == 2
    error_message = "Every database subnet must use an isolated database route table."
  }
}
