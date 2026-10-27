resource "massdriver_group" "catalog_publishers" {
  name        = var.catalog_publishers.group
  description = "Publishes the catalog from GitHub Actions."
}

resource "massdriver_group_policy" "catalog_publishers" {
  group_id   = massdriver_group.catalog_publishers.id
  effect     = "ALLOW"
  actions    = ["repo:create", "repo:push", "repo:pull", "repo:update", "repo:view"]
  conditions = "*"
}

resource "massdriver_service_account" "catalog_publisher" {
  name                     = var.catalog_publishers.service_account
  description              = "GitHub Actions publishing the catalog."
  token_expiration_minutes = var.token_expiration_minutes
}

resource "massdriver_service_account_group_membership" "catalog_publisher" {
  group_id           = massdriver_group.catalog_publishers.id
  service_account_id = massdriver_service_account.catalog_publisher.id
}

# manageGroups is checked against the organization, so this group is
# admin-equal: anything in it can add itself to any group.
resource "massdriver_group" "service_account_managers" {
  name        = var.service_account_managers.group
  description = "Makes service accounts and puts them in groups. Admin-equal."
}

resource "massdriver_group_policy" "service_account_managers" {
  group_id   = massdriver_group.service_account_managers.id
  effect     = "ALLOW"
  actions    = ["organization:manageServiceAccounts", "organization:manageGroups"]
  conditions = "*"
}

resource "massdriver_service_account" "agent_creator" {
  name                     = var.service_account_managers.service_account
  description              = "Gives agents and pipelines their own service accounts."
  token_expiration_minutes = var.token_expiration_minutes
}

resource "massdriver_service_account_group_membership" "agent_creator" {
  group_id           = massdriver_group.service_account_managers.id
  service_account_id = massdriver_service_account.agent_creator.id
}

resource "massdriver_imported_resource" "agent_creator" {
  name          = var.service_account_managers.credential
  resource_type = "massdriver-service-account"
  resource = jsonencode({
    organization_id = var.organization_id
    token           = massdriver_service_account.agent_creator.token
  })
}

resource "massdriver_resource_grant" "agent_creator" {
  resource_id          = massdriver_imported_resource.agent_creator.id
  recipient_conditions = jsonencode(var.massdriver_credential_recipients)
}

resource "massdriver_group" "agents" {
  name        = var.agent_group
  description = "Agents that read and propose. A person approves every change."
}

resource "massdriver_group_policy" "agents" {
  group_id   = massdriver_group.agents.id
  effect     = "ALLOW"
  actions    = ["project:view", "instance:plan", "instance:propose"]
  conditions = "*"
}

resource "massdriver_group" "release" {
  name        = var.release_group
  description = "Repositories that deploy their merged builds to dev."
}

resource "massdriver_group_policy" "release" {
  group_id   = massdriver_group.release.id
  effect     = "ALLOW"
  actions    = ["project:view", "instance:deploy"]
  conditions = jsonencode({ md-environment = var.release_environments })
}

resource "massdriver_project" "this" {
  for_each = var.projects

  identifier  = each.key
  name        = each.value.name
  description = each.value.description
}

locals {
  environments = merge([
    for project, p in var.projects : {
      for env, e in p.environments : "${project}-${env}" => merge(e, { project = project, identifier = env })
    }
  ]...)
}

resource "massdriver_environment" "this" {
  for_each = local.environments

  project_id = massdriver_project.this[each.value.project].id
  identifier = each.value.identifier
  name       = each.value.name
  attributes = each.value.attributes
}
