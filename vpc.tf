locals {
  default_region = "eu-west-1"
  main_vpc_cidr  = "10.0.0.0/16"
  subnets = {
    public = {
      01 = {
        az   = "a",
        cidr = cidrsubnet(local.main_vpc_cidr, 8, 0)
      }
      02 = {
        az   = "b",
        cidr = cidrsubnet(local.main_vpc_cidr, 8, 1)
      }
    }
    private = {
      01 = {
        az   = "a",
        cidr = cidrsubnet(local.main_vpc_cidr, 8, 2)
      }
      02 = {
        az   = "b",
        cidr = cidrsubnet(local.main_vpc_cidr, 8, 3)
      }
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = local.main_vpc_cidr
}

resource "aws_subnet" "public" {
  for_each = local.subnets.public

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = "${local.default_region}${each.value.az}"

  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each = local.subnets.private

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = "${local.default_region}${each.value.az}"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "main" {
  for_each = local.subnets.public

  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each = local.subnets.public

  allocation_id = aws_eip.main[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = local.subnets.public

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = local.subnets.private

  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_ngw" {
  for_each = local.subnets.private

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = local.subnets.private

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
