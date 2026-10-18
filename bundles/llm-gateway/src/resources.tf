resource "massdriver_resource" "endpoint" {
  field = "endpoint"
  name  = "LLM gateway (${join(", ", local.models)})"
  resource = jsonencode({
    base_url             = "http://${aws_instance.gateway.private_dns}:${local.port}/v1"
    region               = local.region
    key_parameter_prefix = local.key_prefix
    default_model        = local.default_model
    models               = local.models
  })

  lifecycle {
    precondition {
      condition     = length(local.models) > 0
      error_message = "Pick at least one Bedrock model or connect a model server."
    }
  }
}
