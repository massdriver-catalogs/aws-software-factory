module "alarm_channel" {
  source      = "massdriver-cloud/aws-alarm-channel/massdriver"
  version     = "~> 0.1"
  md_metadata = var.md_metadata
}

module "server_errors" {
  source  = "massdriver-cloud/aws-metric-alarm/massdriver"
  version = "~> 1.0"

  md_metadata   = var.md_metadata
  sns_topic_arn = module.alarm_channel.arn

  alarm_name   = "${local.name}-5xx"
  display_name = "Server errors"
  message      = "More than 5% of requests to ${local.name} returned 5xx over 5 minutes."

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5

  metric_queries = {
    errors = {
      metric = {
        metric_name = "5xx"
        namespace   = "AWS/ApiGateway"
        period      = 300
        stat        = "Sum"
        dimensions  = { ApiId = aws_apigatewayv2_api.main.id }
      }
    }
    requests = {
      metric = {
        metric_name = "Count"
        namespace   = "AWS/ApiGateway"
        period      = 300
        stat        = "Sum"
        dimensions  = { ApiId = aws_apigatewayv2_api.main.id }
      }
    }
    error_rate = {
      expression  = "IF(requests > 20, 100 * errors / requests, 0)"
      label       = "5xx rate (%)"
      return_data = true
    }
  }
  display_metric_key = "errors"
}
