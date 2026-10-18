resource "massdriver_resource" "network" {
  field = "network"
  name  = "VPC ${var.cidr} (${var.region})"
  resource = jsonencode({
    id                  = aws_vpc.main.id
    region              = var.region
    cidr                = var.cidr
    shared_cidr         = local.shared_cidr
    landing_zone_ranges = local.landing_zone_ranges
    internet_egress     = var.egress != "none"
    availability_zones = [for id in local.zone_ids : {
      id   = id
      name = local.zone_name_by_id[id]
    }]
    route_tables = {
      public   = aws_route_table.public.id
      internal = aws_route_table.internal.id
      private = [for i, rt in aws_route_table.private : {
        availability_zone_id = local.zone_ids[i]
        id                   = rt.id
      }]
    }
    subnets = concat(
      [for s in aws_subnet.public : { id = s.id, cidr = s.cidr_block, availability_zone_id = s.availability_zone_id, tier = "public" }],
      [for s in aws_subnet.private : { id = s.id, cidr = s.cidr_block, availability_zone_id = s.availability_zone_id, tier = "private" }],
    )
  })
}
