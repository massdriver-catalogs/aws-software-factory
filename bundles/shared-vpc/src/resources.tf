resource "massdriver_resource" "network" {
  field = "network"
  name  = "VPC ${var.cidr} (${var.region})"
  resource = jsonencode({
    id              = aws_vpc.main.id
    region          = var.region
    cidr            = var.cidr
    internet_egress = var.egress != "none"
    availability_zones = [for id in local.zone_ids : {
      id   = id
      name = local.zone_name_by_id[id]
    }]
    subnets = concat(
      [for s in aws_subnet.public : { id = s.id, cidr = s.cidr_block, availability_zone_id = s.availability_zone_id, tier = "public" }],
      [for s in aws_subnet.private : { id = s.id, cidr = s.cidr_block, availability_zone_id = s.availability_zone_id, tier = "private" }],
      [for s in aws_subnet.internal : { id = s.id, cidr = s.cidr_block, availability_zone_id = s.availability_zone_id, tier = "internal" }],
    )
  })
}
