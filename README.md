# AWS Software Factory

A Massdriver catalog for running an agentic software factory in your own AWS account. It gives you private models behind one gateway, a disposable VM per developer where coding agents work, GitHub repositories that build container images, the serverless pieces apps run on, agents that work on a schedule, and the automation that turns issues into pull requests and alarms into issues.

Agents never hold cloud credentials. Every infrastructure change goes through Massdriver, under the same policy and approvals as a person.

> This catalog was built for a hands-on workshop: a software factory from an empty AWS account to an issue that becomes a pull request and ships to dev, then agents and sandboxes on top. Follow it in [WORKSHOP.md](WORKSHOP.md), with [the slides](https://docs.google.com/presentation/d/1ARGwirwTusiV72yduIwURHrtN1WamnfgGqjFEQkX7m8/edit?usp=sharing).

## Projects

Together these projects are the software factory. Shared foundations are deployed once; per-developer and per-app pieces get an environment each.

| Project | Holds | Environments |
|---|---|---|
| AWS Account (`aws`) | Budget Guard, Cost Reports | One per AWS account, e.g. `workshop` |
| Networking (`networking`) | Shared VPC | One per account and region, e.g. `shared` |
| AI Platform (`ai`) | LLM Gateway, optional vLLM Model Server | One per AWS account, e.g. `main` |
| CI Platform (`ci`) | GitHub Actions OIDC, GitHub Actions Runners (AI review, issue → PR agent) | One per GitHub organization, e.g. `main` |
| Codebases (`codebases`) | GitHub Repository, ECR Repository | One per app, named after the app's project, e.g. `todoapp` |
| Each app, e.g. Todo App (`todoapp`) | The app on the Lambda Function runtime, HTTP API, DynamoDB Table, User Pool, Static Site, Alarm to Issue | dev, prod, … |
| Agents (`agents`) | Agents, e.g. an SRE agent and a cost agent | One for the organization, e.g. `main` |
| Developer Sandboxes (`devsandboxes`) | Developer Sandbox | One per developer, e.g. `cory` |

Agents read Massdriver and propose through Massdriver, so one Agents project covers every cloud account the organization manages.

Workloads share the VPC's subnets and are kept apart by their own security groups, so adding a developer or an app never claims address space.

## How bundles connect

Bundles exchange resource types, not internals, so one side can change without the other noticing: moving models from Bedrock to a self-hosted GPU changes the gateway, not the sandboxes, runners, agents or functions that use it.

```mermaid
flowchart LR
  subgraph Account[AWS Account]
    BG[budget-guard]
    CR[cost-reports]
  end
  subgraph Networking
    VPC[shared-vpc]
  end
  subgraph AI[AI Platform]
    VLLM[vllm-model-server] -->|model-server| GW[llm-gateway]
  end
  subgraph CI[CI Platform]
    RUN[github-actions-runners]
    OIDC[github-actions-oidc]
  end
  subgraph Agents
    AG[agent]
  end
  subgraph Sandboxes[Developer Sandboxes]
    SB[dev-sandbox]
  end
  subgraph Codebases
    ECR[ecr-repository] -->|aws-ecr-repository| REPO[github-repo]
  end
  subgraph App[Each app]
    UP[user-pool] -->|aws-user-pool| API[http-api]
    API -->|aws-http-api| FN["todoapp<br/>on the lambda-function runtime"]
    DDB[dynamodb-table] -->|aws-dynamodb-table| FN
    API -->|aws-http-api| WEB[static-site]
    A2I[alarm-to-issue]
  end
  subgraph Apps[An app on the runtime]
    T1[dynamodb-table] -->|aws-dynamodb-table| APPL["linkly<br/>on the lambda-function runtime"]
    T2[dynamodb-table] -->|aws-dynamodb-table| APPL
    API2[http-api] -->|aws-http-api| APPL
  end

  VPC -->|aws-vpc| GW & VLLM & SB & RUN & AG & FN
  GW -->|llm-endpoint| RUN & SB & AG & FN
  OIDC -->|aws-github-oidc| REPO
  REPO -->|source-repository| A2I
```

Arrows between projects are environment defaults, not links: the shared resource is set once on the environment that uses it.

Three credentials sit underneath everything: **AWS IAM Role** (`aws-iam-role`), which every bundle deploys with; **GitHub App** (`github-app`), used by the repository, runner, sandbox, agent and alarm bundles; and **Massdriver Service Account** (`massdriver-service-account`), which lets repositories, sandboxes and agents make their own Massdriver identities. All three are environment defaults, so they're set once per environment instead of linked.

## Bundles

| Bundle | What it is |
|---|---|
| `shared-vpc` | A VPC with public, private and internal subnets in each zone, egress (NAT instance or gateways), endpoints and flow logs |
| `budget-guard` | A monthly spending limit for the account, with alerts on actual and forecast spend |
| `cost-reports` | The account's Cost and Usage Report and a read-only user, so Massdriver shows what each instance costs |
| `llm-gateway` | One OpenAI-compatible URL in front of Bedrock models and any self-hosted model; per-consumer keys, usage and budgets |
| `vllm-model-server` | An open-weight model on a GPU you run, reachable only through the gateway |
| `dev-sandbox` | A coding-agent VM per developer: opencode (and optionally Claude Code), the gateway, GitHub through the App, Massdriver tools; reached by SSH over Session Manager or in the browser, with the [Massdriver opencode plugin](https://www.npmjs.com/package/@massdriver/opencode) |
| `agent` | A VM that runs a coding agent on a schedule with a prompt you give it, under its own Massdriver identity. Presets for an SRE agent and a cost agent, a test run of each, and a blank one for your own prompt |
| `github-actions-oidc` | Lets GitHub Actions get short-lived AWS credentials. Once per account |
| `github-actions-runners` | Ephemeral self-hosted runners in the VPC's private subnets, with the gateway, plus the AI review and issue → PR agent workflows |
| `github-repo` | A GitHub repository with a write-once starter app and a pipeline that tests, scans and pushes an arm64 image to ECR. Can adopt an existing repository |
| `ecr-repository` | A container image repository with push and pull policies |
| `http-api` | An API Gateway HTTP API; functions attach their own routes. Optional sign-in |
| `lambda-function` | A function behind the API, with an optional table and access to the gateway's models. Also a runtime that applications run on |
| `dynamodb-table` | An on-demand table with read and read-write policies |
| `user-pool` | Cognito sign-in with a hosted page and a browser app client |
| `static-site` | A private S3 bucket behind CloudFront; serves a connected API's URL at `/config.json` |
| `alarm-to-issue` | Opens a GitHub issue when one of the environment's alarms fires |

Each bundle's README explains its design; its runbook covers what to do when it breaks. Most have presets named for when to use them: **Free Tier** where the defaults stay inside AWS's always-free allowances, **Development** for the cheapest settings that still work well, **Production** for durability and safety.

## Applications

An application is one `massdriver.yaml` on a runtime: its own tables as dependencies, and the environment variables that name them. It has no IaC and no params. The runtime owns the function, its image, routes, memory and sign-in, and gives the app read-write access to every table it brings.

| Application | Runtime | What it is | Tables |
|---|---|---|---|
| `todoapp` | `lambda-function` | The example todo app the factory builds | `todos` |
| `linkly` | `lambda-function` | A link shortener with click counts and a stats page per link | `links`, `clicks` |

Linkly runs in its own project with a `dev` environment: an HTTP API, and the application linked to the API and its two tables. It serves its landing page at `/` and its API under `/api`, so it needs no Static Site. Its GitHub and ECR repositories sit in the Codebases environment `linkly`.


## Repository layout

```
platforms/        Credential types (AWS IAM Role, GitHub App, Massdriver Service Account)
resource-types/   Contracts between bundles
bundles/          OpenTofu bundles
applications/     Applications on the bundles' runtimes
bootstrap/        The projects, groups and canvases above, from one terraform apply
.github/workflows Publishing
```

## Getting started

1. **Publish from GitHub Actions.** First turn on **Settings → General → Grant new bundle repositories to all projects**, or projects can't use what you publish. Create a Massdriver service account with a **1 year** token in a group allowed to publish to the catalog. In the repository's **Settings → Secrets and variables → Actions**, add its key as the secret `MASSDRIVER_API_KEY` and your organization ID as `MASSDRIVER_ORG_ID` (a variable or a secret). Then run **Actions → Publish → Run workflow** with *all* ticked. After that, every push to `main` publishes whatever changed since the last successful publish: credential types and resource types first, then bundles, then applications.
2. **Add credentials** in Massdriver: an **AWS IAM Role** and a **GitHub App**, each following the instructions on its form. Share both with every environment.
3. **Add the identity maker:** a **Massdriver Service Account** credential, which lets repositories, sandboxes and agents make their own identities. Share it only with the Codebases, Developer Sandboxes and Agents projects.
4. **Build the foundations:** AWS Account, Networking, AI Platform and CI Platform.
5. **Add each app as it arrives:** its repository and image repository in a Codebases environment named after it, then its own project. Set **Release to** on the repository, and every merge deploys to dev.
6. **Add Agents and Developer Sandboxes** as people arrive.

## Versioning

Everything publishes as `0.0.0`, which can be republished in place for bundles and resource types alike. Publishing any other version to a repository ends that, development releases included: once a repository holds another version, `0.0.0` can no longer be overwritten there, and the next change needs a version bump.

## License

[Apache License 2.0](LICENSE).
