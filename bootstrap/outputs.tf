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
  }
}

output "environments" {
  value = { for k, e in massdriver_environment.this : k => e.id }
}
