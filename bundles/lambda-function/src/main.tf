locals {
  name        = var.md_metadata.name_prefix
  has_image   = var.image_uri != ""
  has_storage = var.storage != null

  table_policy_arn = local.has_storage ? coalesce(try(var.table_access, null), var.storage.policies[0].arn) : null

  environment = merge(
    { for e in var.environment : e.name => e.value },
    local.has_storage ? {
      TABLE_NAME          = var.storage.name
      TABLE_PARTITION_KEY = var.storage.partition_key.name
    } : {},
  )
}

data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/placeholder.zip"

  source {
    filename = "handler.py"
    content  = file("${path.module}/placeholder/handler.py")
  }
}

resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "function" {
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

resource "aws_iam_role_policy" "logs" {
  name = "write-logs"
  role = aws_iam_role.function.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.function.arn}:*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "table" {
  count      = local.has_storage ? 1 : 0
  role       = aws_iam_role.function.name
  policy_arn = local.table_policy_arn
}

resource "aws_lambda_function" "main" {
  function_name = local.name
  role          = aws_iam_role.function.arn
  architectures = ["arm64"]
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  package_type     = local.has_image ? "Image" : "Zip"
  image_uri        = local.has_image ? var.image_uri : null
  runtime          = local.has_image ? null : "python3.13"
  handler          = local.has_image ? null : "handler.handler"
  filename         = local.has_image ? null : data.archive_file.placeholder.output_path
  source_code_hash = local.has_image ? null : data.archive_file.placeholder.output_base64sha256

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  tracing_config {
    mode = "Active"
  }

  dynamic "environment" {
    for_each = length(local.environment) > 0 ? [1] : []
    content {
      variables = local.environment
    }
  }

  depends_on = [aws_iam_role_policy.logs]
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_apigatewayv2_integration" "main" {
  api_id                 = var.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "main" {
  for_each  = toset(var.routes)
  api_id    = var.api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api.execution_arn}/*/*"
}
