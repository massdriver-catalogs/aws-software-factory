resource "massdriver_resource" "model_server" {
  field = "model_server"
  name  = "${var.model} on ${var.instance_type}"
  resource = jsonencode({
    url                = "http://${aws_instance.server.private_dns}:${local.port}/v1"
    model              = var.model
    region             = local.region
    api_key_secret_arn = aws_secretsmanager_secret.api_key.arn
    security_group_id  = aws_security_group.server.id
  })
}
