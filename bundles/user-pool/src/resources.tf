resource "massdriver_resource" "user_pool" {
  field = "user_pool"
  name  = "User pool ${local.name}"
  resource = jsonencode({
    id          = aws_cognito_user_pool.main.id
    arn         = aws_cognito_user_pool.main.arn
    region      = var.region
    issuer      = "https://${aws_cognito_user_pool.main.endpoint}"
    client_id   = aws_cognito_user_pool_client.web.id
    sign_in_url = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
  })
}
