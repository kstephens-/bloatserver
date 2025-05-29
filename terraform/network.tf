locals {
  vpc_cidr = "10.0.0.0/16"
}

# vpc
resource "aws_vpc" "vpc" {
  cidr_block       = local.vpc_cidr
  instance_tenancy = "default"

  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_dhcp_options" "vpc_dhcp" {
  domain_name         = "us-west-2.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "dns" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.vpc_dhcp.id
}

# subnets
data "aws_availability_zones" "zones" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 2

  availability_zone       = element(data.aws_availability_zones.zones.names, count.index)
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index * 10)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
}

resource "aws_route_table" "public" {
  count = 2

  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

resource "aws_route" "route_public_internet" {
  count = 2

  route_table_id         = element(aws_route_table.public.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id

  depends_on = [aws_route_table_association.public]
}
