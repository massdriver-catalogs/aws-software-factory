data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = var.md_metadata.name_prefix

  slice_bits          = 20 - tonumber(split("/", var.cidr)[1])
  shared_cidr         = cidrsubnet(var.cidr, local.slice_bits, 0)
  landing_zone_ranges = [for i in range(1, pow(2, local.slice_bits)) : cidrsubnet(var.cidr, local.slice_bits, i)]

  # Laid out for three zones regardless of zone_count, so adding a zone never
  # moves an existing subnet.
  shared_blocks = cidrsubnets(local.shared_cidr, 4, 4, 4, 4, 4, 4)

  zone_name_by_id = zipmap(data.aws_availability_zones.available.zone_ids, data.aws_availability_zones.available.names)
  zone_ids        = slice(sort(data.aws_availability_zones.available.zone_ids), 0, var.zone_count)
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-default-deny" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = local.name }
}

resource "aws_subnet" "public" {
  count                               = var.zone_count
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = local.shared_blocks[count.index]
  availability_zone_id                = local.zone_ids[count.index]
  private_dns_hostname_type_on_launch = "resource-name"
  tags                                = { Name = "${local.name}-shared-public-${local.zone_ids[count.index]}" }
}

resource "aws_subnet" "private" {
  count                               = var.zone_count
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = local.shared_blocks[count.index + 3]
  availability_zone_id                = local.zone_ids[count.index]
  private_dns_hostname_type_on_launch = "resource-name"
  tags                                = { Name = "${local.name}-shared-private-${local.zone_ids[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = var.zone_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.zone_count
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-private-${local.zone_ids[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = var.zone_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "internal" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-internal" }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each          = toset(["s3", "dynamodb"])
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id, aws_route_table.internal.id], aws_route_table.private[*].id)
  tags              = { Name = "${local.name}-${each.key}" }
}
