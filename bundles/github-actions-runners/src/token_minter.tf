resource "aws_secretsmanager_secret" "github_app" {
  name                    = "${local.name}/github-app"
  description             = "GitHub App credentials used to register ${local.name} runners"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "github_app" {
  secret_id = aws_secretsmanager_secret.github_app.id
  secret_string = jsonencode({
    owner           = var.github.owner
    app_id          = var.github.app_id
    installation_id = var.github.installation_id
    private_key     = var.github.private_key
  })
}

data "archive_file" "token_minter" {
  type        = "zip"
  output_path = "${path.module}/token-minter.zip"

  source {
    filename = "index.mjs"
    content  = file("${path.module}/templates/token-minter.mjs")
  }
}

resource "aws_cloudwatch_log_group" "token_minter" {
  name              = "/aws/lambda/${local.name}-token-minter"
  retention_in_days = 7
}

resource "aws_iam_role" "token_minter" {
  name = "${local.name}-token-minter"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "token_minter" {
  name = "mint-registration-tokens"
  role = aws_iam_role.token_minter.id
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
        Action   = "ssm:PutParameter"
        Resource = "arn:aws:ssm:${local.region}:${local.account}:parameter${local.token_parameter}"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.token_minter.arn}:*"
      },
    ]
  })
}

resource "aws_lambda_function" "token_minter" {
  function_name    = "${local.name}-token-minter"
  role             = aws_iam_role.token_minter.arn
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 60
  filename         = data.archive_file.token_minter.output_path
  source_code_hash = data.archive_file.token_minter.output_base64sha256

  environment {
    variables = {
      APP_SECRET_ARN               = aws_secretsmanager_secret.github_app.arn
      REGISTRATION_TOKEN_PARAMETER = local.token_parameter
      RUNNER_NAME_PREFIX           = local.name
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.token_minter.name
  }

  depends_on = [aws_iam_role_policy.token_minter, aws_secretsmanager_secret_version.github_app]
}

# Registration tokens last an hour; refreshing every 30 minutes keeps one
# valid for any runner between jobs.
resource "aws_scheduler_schedule" "token_minter" {
  name                = "${local.name}-token-minter"
  schedule_expression = "rate(30 minutes)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.token_minter.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}

resource "aws_iam_role" "scheduler" {
  name = "${local.name}-token-schedule"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "invoke-token-minter"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.token_minter.arn
    }]
  })
}

resource "aws_lambda_invocation" "first_token" {
  function_name = aws_lambda_function.token_minter.function_name
  input         = jsonencode({})

  triggers = {
    code   = data.archive_file.token_minter.output_base64sha256
    secret = aws_secretsmanager_secret_version.github_app.version_id
  }
}
