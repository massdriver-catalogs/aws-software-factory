locals {
  name   = var.md_metadata.name_prefix
  region = var.network.region
  port   = 4000

  key_prefix   = "/${local.name}/keys"
  config_param = "/${local.name}/config"

  bedrock_ids = {
    "gpt-oss-20b"      = "openai.gpt-oss-20b-1:0"
    "gpt-oss-120b"     = "openai.gpt-oss-120b-1:0"
    "qwen3-coder-30b"  = "qwen.qwen3-coder-30b-a3b-v1:0"
    "qwen3-coder-480b" = "qwen.qwen3-coder-480b-a35b-v1:0"
  }

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

  models        = concat(local.has_model_server ? [local.self_hosted_model] : [], var.bedrock_models)
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
    }
  })
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/${local.name}/gateway"
  retention_in_days = var.log_retention_days
}
