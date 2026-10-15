output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.this.id
}

output "availability_zones" {
  description = "Availability Zones used by the networking tiers."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs in availability_zones order; intended for the internet-facing ALB."
  value       = [for key in sort(keys(local.azs)) : aws_subnet.public[key].id]
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs in availability_zones order; intended for ECS tasks."
  value       = [for key in sort(keys(local.azs)) : aws_subnet.private_app[key].id]
}

output "private_db_subnet_ids" {
  description = "Isolated database subnet IDs in availability_zones order; intended for the RDS subnet group."
  value       = [for key in sort(keys(local.azs)) : aws_subnet.private_db[key].id]
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs; one value in single-NAT mode or one per Availability Zone otherwise."
  value       = [for key in sort(keys(local.nat_gateway_azs)) : aws_nat_gateway.this[key].id]
}

output "public_route_table_id" {
  description = "ID of the route table shared by public subnets."
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "IDs of private application route tables in availability_zones order."
  value       = [for key in sort(keys(local.azs)) : aws_route_table.private_app[key].id]
}

output "private_db_route_table_ids" {
  description = "IDs of isolated database route tables in availability_zones order."
  value       = [for key in sort(keys(local.azs)) : aws_route_table.private_db[key].id]
}
