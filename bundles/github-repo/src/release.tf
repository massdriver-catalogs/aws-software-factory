locals {
  release_instance = var.release_instance == null ? "" : var.release_instance
  release_groups   = var.release_groups == null ? [] : var.release_groups
  release = (
    local.has_registry && var.massdriver != null && local.release_instance != "" &&
    length(local.release_groups) > 0 && !var.adopt_existing_repository
  )
  massdriver_url = try(regex("^https?://[^/]+", var.md_metadata.observability.alarm_webhook_url), "https://api.massdriver.cloud")
}

resource "massdriver_service_account" "release" {
  count                    = local.release ? 1 : 0
  provider                 = massdriver.admin
  name                     = "${local.full_name} release"
  description              = "Deploys ${local.full_name} builds to ${local.release_instance}"
  token_expiration_minutes = 525600
}

resource "massdriver_service_account_group_membership" "release" {
  for_each           = local.release ? toset(local.release_groups) : toset([])
  provider           = massdriver.admin
  group_id           = each.key
  service_account_id = massdriver_service_account.release[0].id
}

resource "github_actions_secret" "massdriver" {
  count           = local.release ? 1 : 0
  repository      = github_repository.main.name
  secret_name     = "MASSDRIVER_API_KEY"
  plaintext_value = massdriver_service_account.release[0].token
}

resource "github_actions_variable" "release" {
  for_each = local.release ? {
    MASSDRIVER_ORGANIZATION_ID  = var.massdriver.organization_id
    MASSDRIVER_URL              = local.massdriver_url
    MASSDRIVER_RELEASE_INSTANCE = local.release_instance
  } : {}

  repository    = github_repository.main.name
  variable_name = each.key
  value         = each.value
}

resource "github_repository_file" "release" {
  count = local.release ? 1 : 0

  repository = github_repository.main.name
  branch     = var.default_branch
  file       = ".github/workflows/release.yml"
  content = templatefile("${path.module}/starter/release.yml.tftpl", {
    branch       = var.default_branch
    mass_version = "2.5.0"
  })
  commit_message      = "Add the release workflow"
  overwrite_on_create = false

  lifecycle {
    ignore_changes = [content, commit_message, commit_author, commit_email]
  }

  depends_on = [
    github_repository_file.workflow,
    github_actions_secret.massdriver,
    github_actions_variable.release,
    massdriver_service_account_group_membership.release,
  ]
}
