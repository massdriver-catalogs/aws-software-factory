resource "massdriver_resource" "landing_zone" {
  field = "landing_zone"
  name  = "${local.name} ${var.range}"
  resource = jsonencode({
    name            = local.name
    region          = var.network.region
    vpc_id          = var.network.id
    vpc_cidr        = var.network.cidr
    cidr            = var.range
    shared_cidr     = var.network.shared_cidr
    isolated        = var.isolated
    internet_egress = var.network.internet_egress
    subnets = [for k, s in aws_subnet.main : {
      id                   = s.id
      cidr                 = s.cidr_block
      availability_zone_id = s.availability_zone_id
      tier                 = local.subnets[k].tier
    }]
  })
}
