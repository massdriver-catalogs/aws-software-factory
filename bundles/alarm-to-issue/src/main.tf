locals {
  name = var.md_metadata.name_prefix

  # Every instance in this environment is named <project>-<environment>-<component>,
  # and its alarms start with that name.
  alarm_prefix = "${var.md_metadata.default_tags["md-project"]}-${var.md_metadata.default_tags["md-target"]}-"
}

resource "aws_secretsmanager_secret" "github_app" {
  name                    = "${local.name}/github-app"
  description             = "GitHub App credentials used to open alarm issues for ${local.name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "github_app" {
  secret_id = aws_secretsmanager_secret.github_app.id
  secret_string = jsonencode({
    app_id          = var.github.app_id
    installation_id = var.github.installation_id
    private_key     = var.github.private_key
  })
}

data "archive_file" "handler" {
  type        = "zip"
  output_path = "${path.module}/handler.zip"

  source {
    filename = "index.mjs"
    content  = file("${path.module}/templates/handler.mjs")
  }
}

resource "aws_cloudwatch_log_group" "handler" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 7
}

resource "aws_iam_role" "handler" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "handler" {
  name = "open-alarm-issues"
  role = aws_iam_role.handler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.handler.arn}:*"
      },
    ]
  })
}

resource "aws_lambda_function" "handler" {
  function_name    = local.name
  role             = aws_iam_role.handler.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 30
  filename         = data.archive_file.handler.output_path
  source_code_hash = data.archive_file.handler.output_base64sha256

  environment {
    variables = {
      APP_SECRET_ARN = aws_secretsmanager_secret.github_app.arn
      REPOSITORY     = var.repository.full_name
      HAND_TO_AGENT  = tostring(var.hand_to_agent)
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.handler.name
  }

  depends_on = [aws_iam_role_policy.handler, aws_secretsmanager_secret_version.github_app]
}

resource "aws_cloudwatch_event_rule" "alarms" {
  name        = local.name
  description = "Alarms in ${trimsuffix(local.alarm_prefix, "-")} changing to ALARM or back to OK"
  event_pattern = jsonencode({
    source        = ["aws.cloudwatch"]
    "detail-type" = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [{ prefix = local.alarm_prefix }]
      state     = { value = ["ALARM", "OK"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "handler" {
  rule = aws_cloudwatch_event_rule.alarms.name
  arn  = aws_lambda_function.handler.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowAlarmEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarms.arn
}

resource "aws_lambda_invocation" "test" {
  count         = var.send_test_alarm ? 1 : 0
  function_name = aws_lambda_function.handler.function_name
  input = jsonencode({
    "detail-type" = "CloudWatch Alarm State Change"
    detail = {
      alarmName = "${local.name}-test"
      state = {
        value     = "ALARM"
        reason    = "Test alarm sent from ${local.name} to check that alarms reach this repository."
        timestamp = timestamp()
      }
      configuration = {
        description = jsonencode({ message = "This is a test. Close it once you've seen it." })
      }
    }
  })

  lifecycle {
    ignore_changes = [input]
  }
}
