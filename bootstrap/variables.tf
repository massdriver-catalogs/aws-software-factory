variable "organization_id" {
  description = "The Massdriver organization ID. The Massdriver Service Account credential stores it next to the token."
  type        = string
}

variable "token_expiration_minutes" {
  description = "How long the service account tokens made here stay valid. Changing it replaces the service accounts and their tokens."
  type        = number
  default     = 525600
}

variable "catalog_publishers" {
  description = "The group and service account GitHub Actions uses to publish the catalog. Leave null when publishing is already set up."
  type = object({
    group           = string
    service_account = string
  })
  default = null
}

variable "service_account_managers" {
  description = "The group that can make service accounts and put them in groups, and the service account in it that bundles use to give agents and pipelines their own identities."
  type = object({
    group           = string
    service_account = string
    credential      = string
  })
  default = {
    group           = "Service Account Managers"
    service_account = "Service Account Creator"
    credential      = "Service Account Creator"
  }
}

variable "agent_group" {
  description = "The group agents are put in. It can plan and propose, never deploy, so a person approves every change."
  type        = string
  default     = "Factory Agents"
}

variable "release_group" {
  description = "The group repositories release to dev with. It can deploy only where md-environment matches release_environments."
  type        = string
  default     = "Release to Dev"
}

variable "release_environments" {
  description = "md-environment values the release group can deploy to."
  type        = list(string)
  default     = ["dev"]
}

variable "citizen_developer_group" {
  description = "The group people's sandboxes build with. It can design projects anywhere and change infrastructure only where md-environment matches citizen_developer_environments."
  type        = string
  default     = "Citizen Developers"
}

variable "citizen_developer_environments" {
  description = "md-environment values citizen developers can configure, deploy and decommission in. Everywhere else they can only plan and propose."
  type        = list(string)
  default     = ["dev"]
}

variable "projects" {
  description = "Projects and their environments, keyed by identifier."
  type = map(object({
    name        = string
    description = optional(string)
    environments = map(object({
      name       = string
      attributes = optional(map(string), {})
    }))
  }))
  default = {
    networking = {
      name         = "Networking"
      description  = "The shared VPC every other project runs in."
      environments = { dev = { name = "Dev" } }
    }
    factory = {
      name         = "Software Factory"
      description  = "Shared machinery every app uses: the LLM gateway and model servers, CI runners, review and agents."
      environments = { main = { name = "Main" } }
    }
    codebases = {
      name         = "Codebases"
      description  = "Each app's GitHub repository and image repository, one environment per app."
      environments = { todoapp = { name = "Todo App" } }
    }
    todoapp = {
      name         = "Todo App"
      description  = "Example citizen app: HTTP API, Lambda function and DynamoDB table."
      environments = { dev = { name = "Dev" } }
    }
    devsandboxes = {
      name         = "Developer Sandboxes"
      description  = "One disposable coding-agent VM per developer; each developer gets an environment."
      environments = {}
    }
    agents = {
      name        = "Agents"
      description = "Agents that run on their own, each with its own Massdriver identity."
      environments = {
        main = { name = "Main" }
      }
    }
  }
}

variable "massdriver_credential_recipients" {
  description = "Environment attribute conditions for sharing the Massdriver Service Account credential. It is admin-equal, so share it only with the projects that make release and agent identities."
  type        = map(list(string))
  default     = { md-project = ["codebases", "devsandboxes", "agents"] }
}
