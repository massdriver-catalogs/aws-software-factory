locals {
  name        = var.md_metadata.name_prefix
  has_image   = var.image_uri != ""
  has_storage = var.storage != null

  has_authorizer      = try(var.api.authorizer_id, null) != null
  sign_in_enforced    = var.require_sign_in && local.has_authorizer
  waiting_for_sign_in = var.require_sign_in && !local.has_authorizer

  table_policy_arn = local.has_storage ? coalesce(try(var.table_access, null), var.storage.policies[0].arn) : null

  # The gateway only listens inside the VPC, so a function that uses it has to
  # run there; one that doesn't stays out and keeps its cold starts short.
  has_llm         = var.llm != null
  in_vpc          = local.has_llm && var.network != null
  private_subnets = local.in_vpc ? [for s in var.network.subnets : s.id if s.tier == "private"] : []

  # An application on this runtime brings its own tables as dependencies and
  # names them in its envs; the function reads and writes every one.
  app_env    = { for k, v in try(jsondecode(file("/massdriver/envs.json")), {}) : k => tostring(v) }
  app_tables = { for k, v in try(jsondecode(file("/massdriver/connections.json")), {}) : k => v if k != "storage" && can(v.partition_key) && can(v.policies) }

  environment = merge(
    { for e in var.environment : e.name => e.value },
    local.app_env,
    local.has_storage ? {
      TABLE_NAME          = var.storage.name
      TABLE_PARTITION_KEY = var.storage.partition_key.name
    } : {},
    local.has_llm ? {
      OPENAI_BASE_URL = var.llm.base_url
      OPENAI_API_KEY  = random_password.llm_key[0].result
      OPENAI_MODEL    = var.llm.default_model
    } : {},
  )
}

resource "random_password" "llm_key" {
  count   = local.has_llm ? 1 : 0
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "llm_key" {
  count       = local.has_llm ? 1 : 0
  name        = "${var.llm.key_parameter_prefix}/${local.name}"
  description = "AI Platform key for ${local.name}"
  type        = "SecureString"
  value       = random_password.llm_key[0].result
}

resource "aws_security_group" "function" {
  count       = local.in_vpc ? 1 : 0
  name        = local.name
  description = "Lambda function: outbound only"
  vpc_id      = var.network.id

  egress {
    description = "AI Platform gateway, AWS APIs and the internet via the VPC egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count      = local.in_vpc ? 1 : 0
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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

resource "aws_iam_role_policy_attachment" "app_tables" {
  for_each   = local.app_tables
  role       = aws_iam_role.function.name
  policy_arn = one([for p in each.value.policies : p.arn if p.name == "read-write"])
}

resource "aws_lambda_function" "main" {
  function_name = local.name
  description = (
    local.sign_in_enforced ? "Routes require sign-in" :
    local.waiting_for_sign_in ? "PUBLIC: sign-in requested but the API has no user pool yet" :
    "Routes are public"
  )
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

  dynamic "vpc_config" {
    for_each = local.in_vpc ? [1] : []
    content {
      subnet_ids         = local.private_subnets
      security_group_ids = [aws_security_group.function[0].id]
    }
  }

  dynamic "environment" {
    for_each = length(local.environment) > 0 ? [1] : []
    content {
      variables = local.environment
    }
  }

  lifecycle {
    precondition {
      condition     = !local.has_llm || var.network != null
      error_message = "Using the AI Platform needs the VPC connected too: the gateway only accepts traffic from inside it."
    }
    precondition {
      condition     = !local.has_llm || try(var.network.internet_egress, false)
      error_message = "The VPC has no internet egress, so a function inside it can't reach AWS APIs. Turn egress on in the shared VPC."
    }
  }

  depends_on = [aws_iam_role_policy.logs, aws_iam_role_policy_attachment.vpc]
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
  for_each           = toset(var.routes)
  api_id             = var.api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
  authorization_type = local.sign_in_enforced ? "JWT" : "NONE"
  authorizer_id      = local.sign_in_enforced ? var.api.authorizer_id : null
}

# Browsers send CORS preflights without a token, so an ANY route behind the
# authorizer rejects them and every call from a website fails.
resource "aws_apigatewayv2_route" "preflight" {
  for_each = local.sign_in_enforced ? toset([
    for r in var.routes : replace(r, "/^ANY /", "OPTIONS ")
    if startswith(r, "ANY ") && !contains(var.routes, replace(r, "/^ANY /", "OPTIONS "))
  ]) : toset([])
  api_id             = var.api.id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
  authorization_type = "NONE"
}

# Not a precondition: an app is usually deployed before its user pool exists,
# and failing that first deploy helps no one. The routes stay public until a
# pool is connected and this function is redeployed, and every deploy says so.
check "sign_in" {
  assert {
    condition     = !local.waiting_for_sign_in
    error_message = "Require sign-in is on, but the API has no user pool connected, so these routes are PUBLIC: anyone can call them. Connect a user pool to the HTTP API, then redeploy this function."
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api.execution_arn}/*/*"

  # Swapping the placeholder for an image replaces the function, and AWS drops
  # its permissions with it.
  lifecycle {
    replace_triggered_by = [aws_lambda_function.main]
  }
}
