# Bootstrap

The software factory and the example app, from two commands.

## Before you start

- The catalog is published to your Massdriver organization.
- The **AWS IAM Role** and **GitHub App** credentials are in Massdriver.
- An Organization Admin key, and the GitHub CLI logged in to the GitHub App's organization: `deploy.sh` waits on the app's first build with it.

## Run it

```bash
export MASSDRIVER_API_KEY=...
export MASSDRIVER_ORGANIZATION_ID=...
export TF_VAR_organization_id=$MASSDRIVER_ORGANIZATION_ID
terraform init
terraform apply
./deploy.sh --email you@example.com
```

`terraform apply` makes the groups, the identity maker, the projects and environments, and puts every component on its canvas, linked. `deploy.sh` shares the credentials, sets each environment's defaults, fills each instance with the walkthrough's preset and deploys it in order (AWS Account, Networking, AI Platform, CI Platform, Agents, Codebases, Todo App), then turns on release to dev. The runners reach the gateway in another project, so they get it as a CI Platform default rather than a link. It takes about 30 minutes, mostly the first deploys. Run it again after any failure; it skips what's already provisioned. `./deploy.sh --help` lists its options.

Tokens end up in the state file, so keep the state somewhere private.

## What you get

| What | Default |
|---|---|
| Group that makes service accounts, its service account, and a Massdriver Service Account credential holding its token | Service Account Managers, Service Account Creator |
| Group repositories release with: `project:view`, `instance:deploy` in `dev` | Release to Dev |
| Group agents are put in: `project:view`, `instance:plan`, `instance:propose` | Factory Agents |
| Group people's sandboxes build with: design projects anywhere; configure, deploy and decommission in `dev` | Citizen Developers |
| AWS Account/Workshop | Budget Guard, Cost Reports |
| Networking/Shared | Shared VPC |
| AI Platform/Main | LLM Gateway, and a vLLM Model Server linked to it |
| CI Platform/Main | GitHub Actions OIDC, Factory Runners |
| Agents/Main | SRE Agent, Cost Agent, in the agent group; `agents = false` leaves them out |
| Codebases/Todo App | Image Repository, Source Repository (`todoapp`), releasing to dev |
| Todo App/Dev | Website, API, Todos Table, Todos Function, Users, Alarm to Issue |
| Developer Sandboxes | Empty, ready for one environment per person |
| *Optional:* group that publishes the catalog, and its service account | set `catalog_publishers` |

Every name is a variable. Add an environment per person under `projects.devsandboxes.environments`, and one per app under `projects.codebases.environments`.

Service Account Managers can add anything to any group, so it is equal to Organization Admin. The credential holding its token is shared only with environments whose attributes match `massdriver_credential_recipients`; by default that is the Codebases, Developer Sandboxes and Agents projects.

## What it costs

**About $0.05 an hour, ~$38 a month**, plus model tokens and the agents' runs: the VPC's NAT instance (~$9 a month), the gateway (~$14) and one runner (~$15). The rest is free tier or cents at workshop traffic. The gateway caps each consumer's tokens at $20 a month.

The vLLM Model Server sits on the canvas undeployed. **`./deploy.sh --gpu` deploys it: a GPU at ~$0.80 an hour while it runs**, ~$10 a month stopped. Leave it off unless you mean it. `self_hosted_model = false` leaves it off the canvas.

## What it leaves to you

- Paste the Cost Reports values into **Settings → Integrations → AWS Cost and Usage Reports**. Its operator guide shows the command.
- Confirm the subscription email AWS sends for Budget Guard.
- Your sandbox. Add its environment under Developer Sandboxes; the Massdriver Service Account credential is already shared with it.

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
