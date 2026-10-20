locals {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = local.url
  client_id_list = ["sts.amazonaws.com"]
}

resource "massdriver_resource" "oidc" {
  field = "oidc"
  name  = "GitHub Actions OIDC"
  resource = jsonencode({
    provider_arn = aws_iam_openid_connect_provider.github.arn
    url          = local.url
  })
}
