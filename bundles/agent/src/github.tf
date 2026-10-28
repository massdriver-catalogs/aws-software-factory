locals {
  has_github     = var.github != null
  github_secret  = local.has_github ? aws_secretsmanager_secret.github[0].name : ""
  github_owner   = local.has_github ? var.github.owner : ""
  gh_cli_version = "2.102.0"
  git_name       = "${local.name} agent"
  git_email      = "${local.name}@agent.invalid"
}

# The sandbox keeps its own copy of the App key, readable only by its role, so
# it can mint installation tokens without anyone handing it a token.
resource "aws_secretsmanager_secret" "github" {
  count                   = local.has_github ? 1 : 0
  name                    = "${local.name}/github-app"
  description             = "GitHub App key the ${local.name} sandbox mints tokens with"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "github" {
  count     = local.has_github ? 1 : 0
  secret_id = aws_secretsmanager_secret.github[0].id
  secret_string = jsonencode({
    app_id          = var.github.app_id
    installation_id = var.github.installation_id
    private_key     = var.github.private_key
  })
}
