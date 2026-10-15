locals {
  azs = {
    for index, availability_zone in var.availability_zones : tostring(index) => {
      index                   = index
      availability_zone       = availability_zone
      public_subnet_cidr      = var.public_subnet_cidrs[index]
      private_app_subnet_cidr = var.private_app_subnet_cidrs[index]
      private_db_subnet_cidr  = var.private_db_subnet_cidrs[index]
    }
  }

  nat_gateway_azs = var.single_nat_gateway ? {
    "0" = local.azs["0"]
  } : local.azs
}

check "unique_subnet_cidrs" {
  assert {
    condition = length(distinct(concat(
      var.public_subnet_cidrs,
      var.private_app_subnet_cidrs,
      var.private_db_subnet_cidrs,
    ))) == 6
    error_message = "All six subnet CIDR blocks must be unique."
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.azs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.public_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${each.value.availability_zone}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  for_each = local.azs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.private_app_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-app-${each.value.availability_zone}"
    Tier = "application"
  })
}

resource "aws_subnet" "private_db" {
  for_each = local.azs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.private_db_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-db-${each.value.availability_zone}"
    Tier = "database"
  })
}

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_azs

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.value.availability_zone}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.value.availability_zone}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = local.azs

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-app-${each.value.availability_zone}-rt"
    Tier = "application"
  })
}

resource "aws_route" "private_app_egress" {
  for_each = local.azs

  route_table_id         = aws_route_table.private_app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? "0" : each.key].id
}

resource "aws_route_table_association" "private_app" {
  for_each = local.azs

  subnet_id      = aws_subnet.private_app[each.key].id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table" "private_db" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-db-${each.value.availability_zone}-rt"
    Tier = "database"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = local.azs

  subnet_id      = aws_subnet.private_db[each.key].id
  route_table_id = aws_route_table.private_db[each.key].id
}
