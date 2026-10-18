module "alarm_channel" {
  source      = "massdriver-cloud/aws-alarm-channel/massdriver"
  version     = "~> 0.1"
  md_metadata = var.md_metadata
}

module "nat_gateway_port_allocation" {
  source   = "massdriver-cloud/aws-metric-alarm/massdriver"
  version  = "~> 1.0"
  for_each = { for i, nat in aws_nat_gateway.main : local.zone_ids[i] => nat.id }

  md_metadata   = var.md_metadata
  sns_topic_arn = module.alarm_channel.arn

  alarm_name   = "${local.name}-nat-${each.key}-port-allocation"
  display_name = "NAT gateway ${each.key} out of ports"
  message      = "NAT gateway in ${each.key} is dropping new connections because it ran out of source ports."

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0

  metric_name = "ErrorPortAllocation"
  namespace   = "AWS/NATGateway"
  period      = 300
  statistic   = "Sum"
  dimensions  = { NatGatewayId = each.value }
}

module "nat_instance_status" {
  source  = "massdriver-cloud/aws-metric-alarm/massdriver"
  version = "~> 1.0"
  count   = local.nat_instance ? 1 : 0

  md_metadata   = var.md_metadata
  sns_topic_arn = module.alarm_channel.arn

  alarm_name   = "${local.name}-nat-instance-status"
  display_name = "NAT instance failing status checks"
  message      = "The NAT instance is failing status checks. Private subnets have no internet egress until it recovers."

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = 1

  metric_name = "StatusCheckFailed"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Maximum"
  dimensions  = { InstanceId = aws_instance.nat[0].id }
}
