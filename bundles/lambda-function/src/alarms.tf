module "alarm_channel" {
  source      = "massdriver-cloud/aws-alarm-channel/massdriver"
  version     = "~> 0.1"
  md_metadata = var.md_metadata
}

module "errors" {
  source  = "massdriver-cloud/aws-metric-alarm/massdriver"
  version = "~> 1.0"

  md_metadata   = var.md_metadata
  sns_topic_arn = module.alarm_channel.arn

  alarm_name   = "${local.name}-errors"
  display_name = "Function errors"
  message      = "${local.name} threw errors or timed out on more than 5 invocations in 5 minutes."

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5

  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"
  dimensions  = { FunctionName = aws_lambda_function.main.function_name }
}
