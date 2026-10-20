resource "massdriver_resource" "api" {
  field = "api"
  name  = "HTTP API ${local.name}"
  resource = jsonencode(merge(
    {
      id            = aws_apigatewayv2_api.main.id
      region        = var.region
      endpoint      = aws_apigatewayv2_api.main.api_endpoint
      execution_arn = aws_apigatewayv2_api.main.execution_arn
    },
    var.auth != null ? { authorizer_id = aws_apigatewayv2_authorizer.sign_in[0].id } : {},
  ))
}
