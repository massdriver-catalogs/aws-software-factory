locals {
  components = merge(
    {
      budget  = { at = "account", bundle = "budget-guard", name = "Budget Guard" }
      costs   = { at = "account", bundle = "cost-reports", name = "Cost Reports" }
      vpc     = { at = "networking", bundle = "shared-vpc", name = "Shared VPC" }
      gateway = { at = "ai", bundle = "llm-gateway", name = "LLM Gateway" }
      oidc    = { at = "ci", bundle = "github-actions-oidc", name = "GitHub Actions OIDC" }
      runners = { at = "ci", bundle = "github-actions-runners", name = "Factory Runners" }
    },
    var.self_hosted_model ? {
      gpu = { at = "ai", bundle = "vllm-model-server", name = "vLLM Model Server" }
    } : {},
    var.agents ? {
      sre  = { at = "agents", bundle = "agent", name = "SRE Agent" }
      cost = { at = "agents", bundle = "agent", name = "Cost Agent" }
    } : {},
    var.example_app ? {
      ecr    = { at = "codebases", bundle = "ecr-repository", name = "Image Repository" }
      repo   = { at = "codebases", bundle = "github-repo", name = "Source Repository" }
      web    = { at = "app", bundle = "static-site", name = "Website" }
      api    = { at = "app", bundle = "http-api", name = "API" }
      table  = { at = "app", bundle = "dynamodb-table", name = "Todos Table" }
      fn     = { at = "app", bundle = "lambda-function", name = "Todos Function" }
      users  = { at = "app", bundle = "user-pool", name = "Users" }
      alarms = { at = "app", bundle = "alarm-to-issue", name = "Alarm to Issue" }
    } : {},
  )

  # Links only join components on one canvas; the runners reach the gateway
  # through the ci environment's default instead.
  links = merge(
    var.self_hosted_model ? {
      gateway_model = { from = "gpu", from_field = "model_server", to = "gateway", to_field = "model_server" }
    } : {},
    var.example_app ? {
      repo_registry = { from = "ecr", from_field = "repository", to = "repo", to_field = "registry" }
      api_auth      = { from = "users", from_field = "user_pool", to = "api", to_field = "auth" }
      fn_api        = { from = "api", from_field = "api", to = "fn", to_field = "api" }
      fn_storage    = { from = "table", from_field = "table", to = "fn", to_field = "storage" }
    } : {},
  )
}

resource "massdriver_component" "this" {
  for_each = local.components

  project_id  = massdriver_project.this[var.canvas[each.value.at].project].id
  identifier  = each.key
  name        = each.value.name
  bundle_name = each.value.bundle

  lifecycle {
    precondition {
      condition     = contains(keys(var.projects[var.canvas[each.value.at].project].environments), var.canvas[each.value.at].environment)
      error_message = "canvas.${each.value.at} names an environment that projects doesn't create."
    }
  }
}

resource "massdriver_component_link" "this" {
  for_each = var.link_components ? local.links : {}

  from_component_id = massdriver_component.this[each.value.from].id
  from_field        = each.value.from_field
  to_component_id   = massdriver_component.this[each.value.to].id
  to_field          = each.value.to_field
}
