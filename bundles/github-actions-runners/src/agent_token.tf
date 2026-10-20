locals {
  agent_oidc_audience = "massdriver-agent"
  agent_workflow      = "agent.yml"
}

data "archive_file" "agent_token" {
  type        = "zip"
  output_path = "${path.module}/agent-token.zip"

  source {
    filename = "index.mjs"
    content  = file("${path.module}/templates/agent-token.mjs")
  }
}

resource "aws_cloudwatch_log_group" "agent_token" {
  name              = "/aws/lambda/${local.name}-agent-token"
  retention_in_days = 7
}

resource "aws_iam_role" "agent_token" {
  name = "${local.name}-agent-token"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "agent_token" {
  name = "mint-agent-tokens"
  role = aws_iam_role.agent_token.id
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
        Resource = "${aws_cloudwatch_log_group.agent_token.arn}:*"
      },
    ]
  })
}

resource "aws_lambda_function" "agent_token" {
  function_name    = "${local.name}-agent-token"
  role             = aws_iam_role.agent_token.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 15
  filename         = data.archive_file.agent_token.output_path
  source_code_hash = data.archive_file.agent_token.output_base64sha256

  environment {
    variables = {
      APP_SECRET_ARN = aws_secretsmanager_secret.github_app.arn
      OIDC_AUDIENCE  = local.agent_oidc_audience
      AGENT_WORKFLOW = local.agent_workflow
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.agent_token.name
  }

  depends_on = [aws_iam_role_policy.agent_token]
}

# Public on purpose: every caller must present a GitHub Actions OIDC token,
# which the function verifies before minting anything.
resource "aws_lambda_function_url" "agent_token" {
  function_name      = aws_lambda_function.agent_token.function_name
  authorization_type = "NONE"
}
