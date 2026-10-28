locals {
  massdriver_groups = var.massdriver_groups == null ? [] : var.massdriver_groups
  has_massdriver    = var.massdriver != null && length(local.massdriver_groups) > 0
}

resource "massdriver_service_account" "agent" {
  count                    = local.has_massdriver ? 1 : 0
  provider                 = massdriver.admin
  name                     = "${local.name} sandbox agents"
  description              = "Massdriver access for the agents in the ${local.name} sandbox"
  token_expiration_minutes = 525600
}

resource "massdriver_service_account_group_membership" "agent" {
  for_each           = local.has_massdriver ? toset(local.massdriver_groups) : toset([])
  provider           = massdriver.admin
  group_id           = each.key
  service_account_id = massdriver_service_account.agent[0].id
}

# sandbox-massdriver-login reads this at boot and turns the Massdriver tools on.
resource "aws_secretsmanager_secret" "massdriver" {
  count                   = local.has_massdriver ? 1 : 0
  name                    = local.massdriver_secret
  description             = "Massdriver service account key for the ${local.name} sandbox's agents"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "massdriver" {
  count     = local.has_massdriver ? 1 : 0
  secret_id = aws_secretsmanager_secret.massdriver[0].id
  secret_string = jsonencode({
    api_key         = massdriver_service_account.agent[0].token
    organization_id = var.massdriver.organization_id
    url             = local.massdriver_url
  })
}
