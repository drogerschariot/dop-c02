locals {
  name     = "dop-c02"
  vpc_cidr = "10.0.0.0/16"

  # Local list of subnets compatible with aws_subnet.subnets (cidr_block, availability_zone, is_public).
  subnets = [
    {
      name              = "public-a"
      cidr_block        = "10.0.1.0/24"
      availability_zone = "${local.region}a"
      is_public         = true
    },
    {
      name              = "public-b"
      cidr_block        = "10.0.2.0/24"
      availability_zone = "${local.region}b"
      is_public         = true
    },
    {
      name              = "private-a"
      cidr_block        = "10.0.11.0/24"
      availability_zone = "${local.region}a"
      is_public         = false
    },
    {
      name              = "private-b"
      cidr_block        = "10.0.12.0/24"
      availability_zone = "${local.region}b"
      is_public         = false
    },
  ]

  subnet_map = { for subnet in local.subnets : subnet.name => subnet }
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr
  tags = {
    Name = local.name
  }
}


resource "aws_subnet" "subnets" {
  for_each = local.subnet_map

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.value.name
    Type = each.value.is_public ? "public" : "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = {
    for name, subnet in local.subnet_map : name => subnet
    if subnet.is_public
  }

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public.id
}
