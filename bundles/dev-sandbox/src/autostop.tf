locals {
  idle_minutes = { "30m" = 30, "1h" = 60, "2h" = 120 }
}

resource "aws_cloudwatch_metric_alarm" "idle" {
  count               = var.idle_stop == "never" || local.goal_recurring ? 0 : 1
  alarm_name          = "${local.name}-idle-stop"
  alarm_description   = "Stops ${local.name} after ${var.idle_stop} near zero CPU"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = aws_instance.sandbox.id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = local.idle_minutes[var.idle_stop] / 5
  threshold           = 3
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = ["arn:aws:automate:${local.region}:ec2:stop"]
}

resource "aws_iam_role" "scheduler" {
  count = var.nightly_stop == "off" || local.goal_recurring ? 0 : 1
  name  = "${local.name}-nightly-stop"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler" {
  count = var.nightly_stop == "off" || local.goal_recurring ? 0 : 1
  name  = "stop-sandbox"
  role  = aws_iam_role.scheduler[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:StopInstances"
      Resource = aws_instance.sandbox.arn
    }]
  })
}

resource "aws_scheduler_schedule" "nightly_stop" {
  count                        = var.nightly_stop == "off" || local.goal_recurring ? 0 : 1
  name                         = "${local.name}-nightly-stop"
  schedule_expression          = "cron(${tonumber(split(":", var.nightly_stop)[1])} ${tonumber(split(":", var.nightly_stop)[0])} * * ? *)"
  schedule_expression_timezone = var.timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.sandbox.id] })
  }
}
