# AWS Software Factory

A Massdriver catalog for running an agentic software factory in your own AWS account. It gives you private models behind one gateway, a disposable VM per developer where coding agents work, GitHub repositories that build container images, the serverless pieces apps run on, and the automation that turns issues into pull requests and alarms into issues.

Agents never hold cloud credentials. Every infrastructure change goes through Massdriver, under the same policy and approvals as a person.

## Projects

The bundles are designed for six kinds of project. Shared foundations are deployed once; per-developer and per-app pieces get an environment each.

| Project | Holds | Environments |
|---|---|---|
| Networking | Shared VPC, Budget Guard | One per account and region |
| AI Platform | LLM Gateway, optional vLLM Model Server | One per account and region |
| Developer Sandboxes | Developer Sandbox | One per developer |
| CI Platform | GitHub Actions OIDC, GitHub Actions Runners (AI review, issue → PR agent) | One per GitHub organization |
| Codebases | GitHub Repository, ECR Repository | One per app |
| Each app | HTTP API, Lambda Function, DynamoDB Table, User Pool, Static Site, Alarm to Issue | dev, prod, … |

Workloads share the VPC's subnets and are kept apart by their own security groups, so adding a developer or an app never claims address space.

## How bundles connect

Bundles exchange resource types, not internals, so one side can change without the other noticing: moving the AI Platform from Bedrock to a self-hosted GPU changes the gateway, not the sandboxes, runners or functions that use it.

```mermaid
flowchart LR
  subgraph Networking
    VPC[shared-vpc]
  end
  subgraph AIPlatform[AI Platform]
    VLLM[vllm-model-server] -->|model-server| GW[llm-gateway]
  end
  subgraph Sandboxes[Developer Sandboxes]
    SB[dev-sandbox]
  end
  subgraph CI[CI Platform]
    OIDC[github-actions-oidc]
    RUN[github-actions-runners]
  end
  subgraph Codebases
    ECR[ecr-repository] -->|aws-ecr-repository| REPO[github-repo]
  end
  subgraph App[Each app]
    UP[user-pool] -->|aws-user-pool| API[http-api]
    API -->|aws-http-api| FN[lambda-function]
    DDB[dynamodb-table] -->|aws-dynamodb-table| FN
    A2I[alarm-to-issue]
    WEB[static-site]
  end

  VPC -->|aws-vpc| GW & VLLM & SB & RUN & FN
  GW -->|llm-endpoint| SB & RUN & FN
  OIDC -->|aws-github-oidc| REPO
  REPO -->|source-repository| A2I
```

Two credentials sit underneath everything: **AWS IAM Role** (`aws-iam-role`), which every bundle deploys with, and **GitHub App** (`github-app`), used by the repository, runner, sandbox and alarm bundles. Both are environment defaults, so they're set once per environment instead of linked.

## Bundles

| Bundle | What it is |
|---|---|
| `shared-vpc` | A VPC with public, private and internal subnets in each zone, egress (NAT instance or gateways), endpoints and flow logs |
| `budget-guard` | A monthly spending limit for the account, with alerts on actual and forecast spend |
| `llm-gateway` | One OpenAI-compatible URL in front of Bedrock models and any self-hosted model; per-consumer keys, usage and budgets |
| `vllm-model-server` | An open-weight model on a GPU you run, reachable only through the gateway |
| `dev-sandbox` | A coding-agent VM per developer: opencode (and optionally Claude Code), the gateway, GitHub through the App, Massdriver tools; reached by SSH over Session Manager or in the browser |
| `github-actions-oidc` | Lets GitHub Actions get short-lived AWS credentials. Once per account |
| `github-actions-runners` | Ephemeral self-hosted runners in the VPC's private subnets, with the gateway, plus the AI review and issue → PR agent workflows |
| `github-repo` | A GitHub repository with a write-once starter app and a pipeline that tests, scans and pushes an arm64 image to ECR. Can adopt an existing repository |
| `ecr-repository` | A container image repository with push and pull policies |
| `http-api` | An API Gateway HTTP API; functions attach their own routes. Optional sign-in |
| `lambda-function` | A function behind the API, with optional table and AI Platform access |
| `dynamodb-table` | An on-demand table with read and read-write policies |
| `user-pool` | Cognito sign-in with a hosted page and a browser app client |
| `static-site` | A private S3 bucket behind CloudFront |
| `alarm-to-issue` | Opens a GitHub issue when one of the environment's alarms fires |

Each bundle's README explains its design; its runbook covers what to do when it breaks. Most have presets named for when to use them: **Free Tier** where the defaults stay inside AWS's always-free allowances, **Development** for the cheapest settings that still work well, **Production** for durability and safety.

## Repository layout

```
platforms/        Credential types (AWS IAM Role, GitHub App)
resource-types/   Contracts between bundles
bundles/          OpenTofu bundles
.github/workflows Publishing
```

## Getting started

1. **Publish from GitHub Actions.** Create a Massdriver service account in a group allowed to publish to the catalog. In the repository's **Settings → Secrets and variables → Actions**, add its key as the secret `MASSDRIVER_API_KEY` and your organization ID as `MASSDRIVER_ORG_ID` (a variable or a secret). Then run **Actions → Publish → Run workflow** with *all* ticked. After that, every push to `main` publishes whatever changed since the last successful publish: credential types and resource types first, then bundles.
2. **Add credentials** in Massdriver: an **AWS IAM Role** and a **GitHub App**, each following the instructions on its form. Share both with every environment.
3. **Build the foundations** — Networking, AI Platform, CI Platform — then add Developer Sandboxes, Codebases and apps as people and apps arrive.

## Versioning

Everything publishes as `0.0.0`, which can be republished in place for bundles and resource types alike. Publishing any other version to a repository ends that: once a repository holds a real version, `0.0.0` can no longer be overwritten there.
