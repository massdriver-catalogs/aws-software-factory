output "catalog_publisher_token" {
  description = "Goes in the catalog repository's MASSDRIVER_API_KEY Actions secret."
  value       = one(massdriver_service_account.catalog_publisher[*].token)
  sensitive   = true
}

output "groups" {
  value = {
    catalog_publishers       = one(massdriver_group.catalog_publishers[*].id)
    service_account_managers = massdriver_group.service_account_managers.id
    agents                   = massdriver_group.agents.id
    release                  = massdriver_group.release.id
    citizen_developers       = massdriver_group.citizen_developers.id
  }
}

output "environments" {
  value = { for k, e in massdriver_environment.this : k => e.id }
}

output "deploy" {
  description = "What deploy.sh reads."
  value = {
    environments = { for k, c in var.canvas : k => "${c.project}-${c.environment}" }
    instances = {
      for k, c in local.components : k => "${var.canvas[c.at].project}-${var.canvas[c.at].environment}-${k}"
    }
    massdriver_credential = massdriver_imported_resource.agent_creator.id
    release_group         = massdriver_group.release.id
    repository_name       = var.app_repository_name
  }
}
