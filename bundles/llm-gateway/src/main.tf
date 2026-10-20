locals {
  name   = var.md_metadata.name_prefix
  region = var.network.region
  port   = 4000

  # LiteLLM 1.106.0. Pinned by digest: floating tags have changed startup
  # requirements underneath running gateways.
  image = "ghcr.io/berriai/litellm@sha256:2e4c0371f3a8c28e4da131d77abaa8341cd3b0c2fcc4d34d7c5900431af7b9d0"

  key_prefix   = "/${local.name}/keys"
  config_param = "/${local.name}/config"
  usage_param  = "/${local.name}/usage"

  # USD per million tokens, input and output, at us-east-1 on-demand rates.
  # Budgets are enforced on these estimates; Cost Explorer has the exact bill.
  bedrock_prices = {
    "kimi-k3"          = { input = 3.30, output = 16.50 }
    "kimi-k2-5"        = { input = 0.60, output = 3.00 }
    "qwen3-coder-next" = { input = 0.22, output = 1.80 }
    "gpt-oss-120b"     = { input = 0.15, output = 0.60 }
    "gpt-oss-20b"      = { input = 0.07, output = 0.30 }
  }

  bedrock_ids = {
    "kimi-k3"          = "us.moonshotai.kimi-k3"
    "kimi-k2-5"        = "moonshotai.kimi-k2.5"
    "qwen3-coder-next" = "qwen.qwen3-coder-next"
    "gpt-oss-120b"     = "openai.gpt-oss-120b-1:0"
    "gpt-oss-20b"      = "openai.gpt-oss-20b-1:0"
  }

  # Cross-region profiles (us.*) need the profile and the model in every
  # region the profile can route to.
  bedrock_arns = flatten([for m in var.bedrock_models : startswith(local.bedrock_ids[m], "us.") ? [
    "arn:aws:bedrock:${local.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${local.bedrock_ids[m]}",
    "arn:aws:bedrock:*::foundation-model/${trimprefix(local.bedrock_ids[m], "us.")}",
    ] : [
    "arn:aws:bedrock:${local.region}::foundation-model/${local.bedrock_ids[m]}",
  ]])

  has_model_server  = var.model_server != null
  self_hosted_model = local.has_model_server ? "self-hosted-${var.model_server.model}" : null

  bedrock_models = [for m in var.bedrock_models : {
    model_name     = m
    litellm_params = { model = "bedrock/${local.bedrock_ids[m]}", aws_region_name = local.region }
  }]
  self_hosted_models = local.has_model_server ? [{
    model_name = local.self_hosted_model
    litellm_params = {
      model    = "openai/${var.model_server.model}"
      api_base = var.model_server.url
      api_key  = data.aws_secretsmanager_secret_version.model_server[0].secret_string
    }
  }] : []

  models        = concat(var.bedrock_models, local.has_model_server ? [local.self_hosted_model] : [])
  default_model = local.models[0]

  private_subnets = [for s in var.network.subnets : s if s.tier == "private"]
}

data "aws_secretsmanager_secret_version" "model_server" {
  count     = local.has_model_server ? 1 : 0
  secret_id = var.model_server.api_key_secret_arn
}

resource "random_password" "master_key" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "master_key" {
  name                    = "${local.name}/master-key"
  description             = "Admin key for the ${local.name} LLM gateway"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "master_key" {
  secret_id     = aws_secretsmanager_secret.master_key.id
  secret_string = "sk-${random_password.master_key.result}"
}

resource "aws_ssm_parameter" "config" {
  name = local.config_param
  type = "SecureString"
  value = yamlencode({
    model_list = concat(local.self_hosted_models, local.bedrock_models)
    general_settings = {
      custom_auth = "custom_auth.user_api_key_auth"
    }
    litellm_settings = {
      drop_params = true
      callbacks   = "usage_tracking.usage_tracker"
    }
  })
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/${local.name}/gateway"
  retention_in_days = var.log_retention_days
}

resource "aws_dynamodb_table" "usage" {
  name         = "${local.name}-usage"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "consumer"
  range_key    = "month"

  attribute {
    name = "consumer"
    type = "S"
  }

  attribute {
    name = "month"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_ssm_parameter" "usage" {
  name = local.usage_param
  type = "String"
  value = jsonencode({
    table              = aws_dynamodb_table.usage.name
    region             = local.region
    prices             = { for m in var.bedrock_models : m => local.bedrock_prices[m] }
    default_budget_usd = var.monthly_budget_usd
    overrides          = { for o in var.budget_overrides : o.consumer => o.monthly_budget_usd }
  })
}
