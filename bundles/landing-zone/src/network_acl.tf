locals {
  # From the internet, only return traffic (ephemeral ports) and web ports are
  # let in. Security groups do the fine-grained filtering.
  internet_ingress = [
    { rule = 300, protocol = "tcp", from = 1024, to = 65535 },
    { rule = 310, protocol = "udp", from = 1024, to = 65535 },
    { rule = 320, protocol = "tcp", from = 443, to = 443 },
    { rule = 330, protocol = "tcp", from = 80, to = 80 },
  ]

  # Order matters: own range and shared services are allowed before the rest
  # of the VPC is denied.
  isolation = var.isolated ? [
    { rule = 100, action = "allow", cidr = var.range },
    { rule = 110, action = "allow", cidr = var.network.shared_cidr },
    { rule = 200, action = "deny", cidr = var.network.cidr },
    ] : [
    { rule = 100, action = "allow", cidr = var.network.cidr },
  ]
}

resource "aws_network_acl" "main" {
  vpc_id     = var.network.id
  subnet_ids = [for s in aws_subnet.main : s.id]
  tags       = { Name = local.name }
}

resource "aws_network_acl_rule" "vpc_ingress" {
  for_each       = { for r in local.isolation : tostring(r.rule) => r }
  network_acl_id = aws_network_acl.main.id
  egress         = false
  rule_number    = each.value.rule
  rule_action    = each.value.action
  protocol       = "-1"
  cidr_block     = each.value.cidr
}

resource "aws_network_acl_rule" "vpc_egress" {
  for_each       = { for r in local.isolation : tostring(r.rule) => r }
  network_acl_id = aws_network_acl.main.id
  egress         = true
  rule_number    = each.value.rule
  rule_action    = each.value.action
  protocol       = "-1"
  cidr_block     = each.value.cidr
}

resource "aws_network_acl_rule" "internet_ingress" {
  for_each       = { for r in local.internet_ingress : tostring(r.rule) => r }
  network_acl_id = aws_network_acl.main.id
  egress         = false
  rule_number    = each.value.rule
  rule_action    = "allow"
  protocol       = each.value.protocol
  from_port      = each.value.from
  to_port        = each.value.to
  cidr_block     = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "internet_egress" {
  network_acl_id = aws_network_acl.main.id
  egress         = true
  rule_number    = 300
  rule_action    = "allow"
  protocol       = "-1"
  cidr_block     = "0.0.0.0/0"
}
