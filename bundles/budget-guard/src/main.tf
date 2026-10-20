data "aws_caller_identity" "current" {}

locals {
  name = var.md_metadata.name_prefix
}

# Unencrypted on purpose: AWS Budgets can't publish to a topic encrypted with
# the AWS-managed SNS key, and spend alerts aren't sensitive.
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-budget"
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBudgets"
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.alerts.arn
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_budgets_budget" "monthly" {
  name         = local.name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = toset(var.alert_at_percent)
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
      subscriber_email_addresses = var.alert_emails
    }
  }

  dynamic "notification" {
    for_each = var.alert_on_forecast ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
      subscriber_email_addresses = var.alert_emails
    }
  }

  depends_on = [aws_sns_topic_policy.alerts]
}
