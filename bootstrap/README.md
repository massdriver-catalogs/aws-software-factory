# Bootstrap

Stands up the groups, service accounts, projects and environments an organization needs before anyone starts building on the canvas.

| What | Default |
|---|---|
| Group that makes service accounts, its service account, and a Massdriver Service Account credential holding its token | Service Account Managers, Service Account Creator |
| Group repositories release with: `project:view`, `instance:deploy` in `dev` | Release to Dev |
| Group agents are put in: `project:view`, `instance:plan`, `instance:propose` | Factory Agents |
| Projects and environments | Networking/Dev, Software Factory/Main, Codebases/Todo App, Todo App/Dev, Developer Sandboxes, Agents/Main |
| *Optional:* group that publishes the catalog, and its service account | set `catalog_publishers` |

Every name is a variable. Add people's sandbox environments under `projects.devsandboxes.environments`.

Service Account Managers can add anything to any group, so it is equal to Organization Admin. The credential holding its token is shared only with environments whose attributes match `massdriver_credential_recipients`; by default that is the Codebases, Developer Sandboxes and Agents projects.

## Run it

The credential needs the Massdriver Service Account type, so publish the catalog first. Use an Organization Admin key. Tokens end up in the state file, so keep the state somewhere private.

```bash
export MASSDRIVER_API_KEY=...
export MASSDRIVER_ORGANIZATION_ID=...
export TF_VAR_organization_id=$MASSDRIVER_ORGANIZATION_ID
terraform init
terraform apply
```

## After it

These have no Terraform resource yet; set them in Massdriver:

- The AWS IAM Role and GitHub App credentials, shared with all environments.
- Each environment's defaults:

  | Environment | Defaults |
  |---|---|
  | Networking/Dev | AWS IAM Role |
  | Software Factory/Main | AWS IAM Role, Shared VPC, GitHub App |
  | Codebases/Todo App | AWS IAM Role, GitHub App, GitHub Actions OIDC, Massdriver Service Account |
  | Todo App/Dev, each sandbox | AWS IAM Role, Shared VPC, LLM Gateway endpoint, GitHub App |
  | Agents/Main | AWS IAM Role, Shared VPC, LLM Gateway endpoint, GitHub App, Massdriver Service Account |

- The AWS Cost and Usage Reports integration.

## Organizations that already have these

Import what exists before applying, or apply makes duplicates. Projects import by identifier and service accounts by ID; memberships take `<group_id>/<service_account_id>`:

```hcl
import {
  to = massdriver_project.this["agents"]
  id = "agents"
}

import {
  to = massdriver_service_account_group_membership.agent_creator
  id = "<group_id>/<service_account_id>"
}
```

An imported service account has no token, so the credential keeps the token it already has: import it too, or leave the credential out.
