locals {
  push_policy_arn = local.has_registry ? one([for p in var.registry.policies : p.arn if p.name == "push"]) : null
}

resource "aws_iam_role" "push" {
  count = local.has_registry ? 1 : 0
  name  = "${local.name}-push"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.github_oidc.provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${local.full_name}:ref:refs/heads/${var.default_branch}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "push" {
  count      = local.has_registry ? 1 : 0
  role       = aws_iam_role.push[0].name
  policy_arn = local.push_policy_arn
}

# Docker login needs a registry-wide token; the push policy covers the repository itself.
resource "aws_iam_role_policy" "ecr_login" {
  count = local.has_registry ? 1 : 0
  name  = "ecr-login"
  role  = aws_iam_role.push[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ecr:GetAuthorizationToken"
      Resource = "*"
    }]
  })
}

resource "github_actions_variable" "push" {
  for_each = local.has_registry ? {
    AWS_REGION         = var.registry.region
    AWS_ROLE_ARN       = aws_iam_role.push[0].arn
    ECR_REPOSITORY_URL = var.registry.url
  } : {}

  repository    = github_repository.main.name
  variable_name = each.key
  value         = each.value
}
