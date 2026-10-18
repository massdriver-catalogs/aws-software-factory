locals {
  name  = var.md_metadata.name_prefix
  zones = var.network.availability_zones

  # Three zones' worth of space is always reserved so a zone added to the VPC
  # later slots in without moving anything: private /22s, then public and
  # internal /25s.
  blocks = cidrsubnets(var.range, 2, 2, 2, 5, 5, 5, 5, 5, 5)

  private_route_table = { for rt in var.network.route_tables.private : rt.availability_zone_id => rt.id }

  subnets = merge(
    { for i, z in local.zones : "private-${z.id}" => { tier = "private", zone = z.id, cidr = local.blocks[i], route_table = local.private_route_table[z.id] } },
    { for i, z in local.zones : "public-${z.id}" => { tier = "public", zone = z.id, cidr = local.blocks[i + 3], route_table = var.network.route_tables.public } },
    { for i, z in local.zones : "internal-${z.id}" => { tier = "internal", zone = z.id, cidr = local.blocks[i + 6], route_table = var.network.route_tables.internal } },
  )
}

resource "aws_subnet" "main" {
  for_each                            = local.subnets
  vpc_id                              = var.network.id
  cidr_block                          = each.value.cidr
  availability_zone_id                = each.value.zone
  private_dns_hostname_type_on_launch = "resource-name"
  tags = {
    Name = "${local.name}-${each.key}"
    Tier = each.value.tier
  }
}

resource "aws_route_table_association" "main" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = each.value.route_table
}
