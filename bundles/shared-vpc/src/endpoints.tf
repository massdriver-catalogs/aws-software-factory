locals {
  endpoint_groups = {
    ssm            = ["ssm", "ssmmessages", "ec2messages"]
    ecr            = ["ecr.api", "ecr.dkr"]
    sts            = ["sts"]
    logs           = ["logs"]
    secretsmanager = ["secretsmanager"]
    bedrock        = ["bedrock-runtime"]
  }
  interface_endpoints = toset(flatten([for group in var.private_endpoints : local.endpoint_groups[group]]))
}

resource "aws_security_group" "endpoints" {
  count       = length(local.interface_endpoints) > 0 ? 1 : 0
  name        = "${local.name}-endpoints"
  description = "Interface endpoints: HTTPS from the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-${each.key}" }
}
