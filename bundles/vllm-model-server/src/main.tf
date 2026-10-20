locals {
  name   = var.md_metadata.name_prefix
  region = var.network.region
  port   = 8000
  image  = "vllm/vllm-openai:v0.32.0"

  models = {
    "gpt-oss-20b" = {
      repo          = "openai/gpt-oss-20b"
      tool_parser   = "openai"
      min_gpu_gb    = 24
      max_model_len = 65536
    }
    "qwen3-coder-30b" = {
      repo          = "Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8"
      tool_parser   = "qwen3_coder"
      min_gpu_gb    = 48
      max_model_len = 65536
    }
  }
  gpu_gb = {
    "g6.xlarge"  = 24
    "g5.xlarge"  = 24
    "g6e.xlarge" = 48
  }
  model = local.models[var.model]

  private_subnets = [for s in var.network.subnets : s if s.tier == "private" && contains(data.aws_ec2_instance_type_offerings.gpu.locations, s.availability_zone_id)]
}

data "aws_caller_identity" "current" {}

data "aws_ec2_instance_type_offerings" "gpu" {
  location_type = "availability-zone-id"
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

data "aws_servicequotas_service_quota" "gpu_vcpus" {
  service_code = "ec2"
  quota_code   = "L-DB2E81BA"
}

data "aws_ssm_parameter" "gpu_ami" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-amazon-linux-2023/latest/ami-id"
}

resource "random_password" "api_key" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${local.name}/api-key"
  description             = "API key for the ${local.name} model server"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = random_password.api_key.result
}

resource "aws_cloudwatch_log_group" "server" {
  name              = "/${local.name}/vllm"
  retention_in_days = var.log_retention_days
}
