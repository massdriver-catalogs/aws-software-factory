# Workshop notes

Building a Citizen Developer Agentic Software Factory on Self-Hosted Models in Your Own VM Sandbox in Under an Hour

The catalog in this repo is the product; the workshop is one path through it.

**Slides:** [Building an agentic software factory](https://docs.google.com/presentation/d/1ARGwirwTusiV72yduIwURHrtN1WamnfgGqjFEQkX7m8/edit?usp=sharing)

## Scope

Everything runs live; nothing is take-home. The factory is the point of the workshop.

1. **Foundation:** account guardrails, the network, the AI Platform (models), the CI Platform (runners).
2. **An app:** its codebase (repository and image repository), API, function, table, website and sign-in.
3. **The factory:** an issue that an agent turns into a pull request, CI and AI review on that pull request, a merge that ships a new image, and an alarm that opens the next issue.
4. **Agents:** an SRE agent and a cost agent that run on a schedule and propose changes a person approves.
5. **A developer sandbox:** where you vibe code a new app and ship it to dev.

Everything through step 10 happens in the browser: GitHub, the AWS Console and Massdriver. The terminal only comes out to work inside the agents and the sandbox.

**Short on time?** Do steps 1–4, then take the **⏩ optional shortcut** right after step 4: it builds steps 5–9 for you.

## How it fits together

### Projects and environment defaults

Each box is a project and its environment. Arrows are environment defaults: one project's output, shared to another project's environment, that every bundle there connects to without a link.

```mermaid
flowchart LR
  CRED[("Credentials: AWS IAM Role, GitHub App")]
  MDSA[("Massdriver Service Account credential")]
  ACCT["AWS Account · workshop"]
  NET["Networking · shared"]
  AI["AI Platform · main"]
  CI["CI Platform · main"]
  AG["Agents · main"]
  CB["Codebases · todoapp, your app"]
  APP["Todo App · dev"]
  YA["Your app · dev"]
  DS["Developer Sandboxes · cory"]
  MD{{Massdriver}}

  CRED --> ACCT & NET & AI & CI & AG & CB & APP & YA & DS
  MDSA --> CB & AG & DS
  NET -->|network| AI & CI & AG & APP & DS
  AI -->|LLM endpoint| CI & AG & APP & DS
  CI -->|GitHub OIDC| CB
  CB -->|repository, remote reference| APP
  AG -->|read, plan, propose| MD
  CB -->|release to dev| MD
  DS -->|design, deploy in dev| MD
  MD --> APP & YA
```

### On the canvas

Each box is a bundle as it sits on its project's canvas. Solid arrows are canvas links; dashed arrows arrive as environment defaults.

```mermaid
flowchart LR
  subgraph ACCT[AWS Account]
    BG[Budget Guard]
    CR[Cost Reports]
  end
  subgraph NET[Networking]
    VPC[Shared VPC]
  end
  subgraph AI[AI Platform]
    GPU["vLLM Model Server, undeployed"] -->|model_server| GW[LLM Gateway]
  end
  subgraph CI[CI Platform]
    OIDC[GitHub Actions OIDC]
    RUN[Factory Runners]
  end
  subgraph AG[Agents]
    SRE["SRE Agent: agent"]
    COST["Cost Agent: agent"]
  end
  subgraph CB[Codebases]
    ECR[ECR Repository] -->|registry| REPO[GitHub Repository]
  end
  subgraph APP[Todo App]
    USR[User Pool] -->|auth| API[HTTP API]
    API -->|api| FN[Lambda Function]
    TBL[DynamoDB Table] -->|storage| FN
    WEB[Static Site]
    A2I[Alarm to Issue]
  end
  subgraph YA[Your app]
    YT1[DynamoDB Table] -->|its first table| YAPP["Your app: an application on lambda-function"]
    YT2[DynamoDB Table] -->|its second table| YAPP
    YAPI[HTTP API] -->|api| YAPP
    YWEB[Static Site]
  end
  subgraph DS[Developer Sandboxes]
    SB[Developer Sandbox]
  end

  VPC -.-> GW & RUN & SRE & COST & FN & SB
  GW -.-> RUN & SRE & COST & FN & SB
  OIDC -.-> REPO
  SB -.->|designs and deploys| YA
  REPO -.->|remote reference| A2I
```

Together these projects are the software factory. Each has a job:

| Project | Environment | Holds |
|---|---|---|
| **AWS Account** (`aws`) | `workshop` | Budget Guard, Cost Reports: account-level setup |
| **Networking** (`networking`) | `shared` | The Shared VPC every other project runs in |
| **AI Platform** (`ai`) | `main` | LLM Gateway, optional vLLM Model Server |
| **CI Platform** (`ci`) | `main` | GitHub Actions OIDC, Factory Runners |
| **Codebases** (`codebases`) | One per app, named after its project, e.g. `todoapp` | Each app's GitHub repository and ECR repository |
| **Todo App** (`todoapp`) | `dev` | The example app |
| **Agents** (`agents`) | `main` | SRE Agent and Cost Agent, both the Agent bundle |
| **Developer Sandboxes** (`devsandboxes`) | One per person, e.g. `cory` | Each person's sandbox |

The runners get the gateway as a CI Platform default. The agents read Massdriver and propose through it, so one Agents project covers every cloud account.

## Attendee prerequisites (registration email, not day-of)

About 40 minutes, emailed ahead as a separate guide. Nothing gets connected to Massdriver beforehand: a new org has no credential types until the catalog is published to it in step 2.

1. **Massdriver account and organization** (~5 min). Note the org ID.
2. **AWS role for Massdriver** (~10 min). Attendees make up their own External ID, create a role trusting account `308878630280` with that External ID and AdministratorAccess, and note the External ID and the role ARN.
3. **GitHub organization** (~3 min), on the Free plan. GitHub Apps can't create repositories under a personal account.
4. **GitHub App** (~15 min), with the permissions in step 4 below, installed on all repositories. Note the App ID and Installation ID, and keep the `.pem` key safe.
5. *Optional, not recommended for the workshop:* **GPU quota** for the self-hosted model. Request "Running On-Demand G and VT instances" ≥ 4 in us-east-1 a week ahead. Without it, everything runs on Bedrock. The GPU costs ~$0.80 an hour while it runs.
6. *Optional:* **AWS CLI and Session Manager plugin**, for a terminal instead of the browser.

They bring: org ID, role ARN, External ID, GitHub org login, App ID, Installation ID, and the `.pem` file.

> [!WARNING]
> **Three things cost real money:**
> 1. **The GPU** (step 7, optional): ~$0.80 an hour while it runs. **Skip it for the workshop.**
> 2. **The SRE agent's tokens** (step 11): its test run costs ~$0.15, but on duty it runs every 10 minutes, ~$0.75 an hour. Remove the agents when you're done.
> 3. **Anything left running afterwards**: ~$125 a month with no GPU, plus tokens. Do step 14 before you leave.
>
> Every step's cost is in the appendix.

## Steps

Costs are per month unless noted. Every pick is the cheapest option that doesn't hurt the experience.

### 0. Set up the mass CLI

The walkthrough runs in the browser; the CLI is for the bootstrap shortcut, the agents and your sandbox.

**Install on Mac:**

```bash
brew install massdriver
```

**Install on Linux** (or on a Mac without Homebrew):

```bash
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
curl -fsSL "https://github.com/massdriver-cloud/mass/releases/download/2.5.0/mass-2.5.0-$OS-$ARCH.tar.gz" | tar -xz mass
sudo mv mass /usr/local/bin/
```

**Sign in with an access token.** In Massdriver, click your email at the top right, then **Access tokens → New token**. A token works in one organization, so pick yours. Copy it; it's shown once. Your organization ID is the part of any Massdriver URL right after `/orgs/`.

![Account → Access tokens → New token](assets/images/step-00-access-tokens.png)

```bash
mkdir -p ~/.config/massdriver
cat > ~/.config/massdriver/config.yaml <<'YAML'
version: 1
profiles:
  default:
    organization_id: <your-org-id>
    api_key: <your-access-token>
YAML
chmod 600 ~/.config/massdriver/config.yaml
mass whoami
```

`mass whoami` prints your name and organization. `MASSDRIVER_ORGANIZATION_ID` and `MASSDRIVER_API_KEY` in the environment work too, and override the file.

### 1. Get the catalog into your GitHub organization

1. Open `github.com/massdriver-catalogs/aws-software-factory` and **Fork** it into your organization (or **Use this template → Create a new repository**).
2. Forks start with Actions turned off. Open the fork's **Actions** tab and click **I understand my workflows, go ahead and enable them**.

### 2. Let GitHub publish the catalog to Massdriver

1. In Massdriver: **Settings → General**, turn on **Grant new bundle repositories to all projects**. Without it, a project can't use a bundle until its repository is granted to it.
2. **Settings → Service accounts → New service account**. Name it `github-publisher`, set **Default Access Token Expiration** to **1 year** (the default is 7 days, and publishing stops when it lapses), and copy its token; it's shown once.
3. Put it in a group that can publish to the catalog, e.g. **Catalog Publishers**, whose policy allows `repo:create`, `repo:push`, `repo:pull`, `repo:update` and `repo:view` on `*`. **Organization Admin** also works but grants far more.
4. In the fork on GitHub: **Settings → Secrets and variables → Actions**.
   - **Secrets → New repository secret:** `MASSDRIVER_API_KEY` = the key.
   - **Variables → New repository variable:** `MASSDRIVER_ORG_ID` = your Massdriver organization's ID. A secret with that name works too.
5. **Actions → Publish → Run workflow**, tick **Publish everything, not just what changed**, **Run workflow**. In a few minutes every credential type, resource type and bundle is in your Massdriver catalog. From now on, every push to `main` publishes what changed.

![Run the Publish workflow with Publish everything ticked](assets/images/step-02-run-publish.jpg)

### 3. Connect AWS (~2 minutes)

The role was created in the prerequisites; now that the catalog is published, Massdriver has the **AWS IAM Role** credential type to put it in.

1. In Massdriver: **Resources → Import Resource → aws-iam-role**. Name it, paste your External ID and the role ARN, and **Import Resource**. The form's setup instructions repeat how the role was made.
2. Open the new resource and **Share** it with all environments, so every project can use it as a default.

![Import a Resource: pick a resource type](assets/images/step-03-import-resource.jpg)

![The AWS IAM Role form](assets/images/step-03-aws-iam-role.jpg)

Bedrock's open-weight models, Kimi included, are enabled by default. Nothing else to turn on.

### 4. Connect GitHub (~2 minutes)

1. In Massdriver: **Resources → Import Resource → github-app**. Fill in the App ID, paste the whole `.pem` file into **Private Key**, then the Installation ID and your organization's login, and **Import Resource**.
2. **Share** it with all environments.

![The GitHub App form](assets/images/step-04-github-app.jpg)

> [!TIP]
> ## ⏩ OPTIONAL SHORTCUT: skip from here to [step 10](#10-the-factory-live)
>
> **After steps 1–4, one Terraform apply and one script build steps 5–9 for you:** the groups and identity maker, every project, the platforms, the codebase and the example app, release to dev, and the agents. About 30 minutes, mostly waiting on deploys. Needs Terraform, the GitHub CLI logged in to your GitHub organization, and an Organization Admin access token.
>
> ```bash
> cd bootstrap
> export MASSDRIVER_API_KEY=<admin-access-token>
> export MASSDRIVER_ORGANIZATION_ID=<your-org-id>
> export TF_VAR_organization_id=$MASSDRIVER_ORGANIZATION_ID
> terraform init && terraform apply
> ./deploy.sh --email you@example.com
> ```
>
> **Then:** paste the Cost Reports values by hand (step 6), and **continue at [step 10](#10-the-factory-live), item 3**.
>
> - The vLLM Model Server goes on the AI Platform canvas, linked to the gateway, but stays undeployed unless you add `--gpu`.
> - The agents start on duty on the **SRE Agent** and **Cost Agent** presets: ~$0.75 an hour in tokens. Set `agents = false` in `terraform.tfvars` to leave them out. To see their tests, start step 11 at item 2: pick their test run presets and deploy.

### 5. Groups and the identity maker

Repositories, agents and your sandbox each get their own Massdriver identity. One credential makes them; groups decide what each can do.

1. **Groups.** **Settings → Groups → New group**, then **Add policy** on each:
   - One for the identity maker, e.g. **Service Account Managers**, allowing `organization:manageServiceAccounts` and `organization:manageGroups` on `*`.
   - One for releases, e.g. **Release to Dev**, with two policies: `project:view` with no conditions, and `instance:deploy` where `md-environment` is `dev`.
   - One for agents, e.g. **Factory Agents**, allowing `project:view`, `instance:plan` and `instance:propose` on `*`. No `instance:deploy`, so a person approves every change.
   - One for builders, e.g. **Citizen Developers**, with three policies:
     - Allow `project:create`, `project:view`, `project:design`, `environment:create`, `repo:view`, `resource:view`, `instance:plan` and `instance:propose` on `*`.
     - Allow `environment:configure`, `instance:configure`, `instance:deploy` and `instance:decommission` where `md-environment` is `dev`.
     - Allow `environment:create`, `environment:configure`, `instance:configure`, `instance:deploy` and `instance:decommission` where `md-project` is `codebases`. An app's repository and image repository live there, outside dev.

![Settings → Groups](assets/images/step-05-groups.jpg)

![Create a group](assets/images/step-05-new-group.jpg)

![A policy: instance:deploy where md-environment is dev](assets/images/step-05-policy.jpg)

![The group and its policy](assets/images/step-05-group-policies.jpg)
2. **The identity maker.** **Settings → Service accounts → New service account**, e.g. `Service Account Creator`, with a **1 year** token expiration. Copy its token, and add it to the identity maker's group under **Service accounts** on the group's page. Then **Resources → Import Resource → massdriver-service-account** with your organization ID (**Settings → Copy organization ID**) and that token. **Share** it only with the Codebases, Developer Sandboxes and Agents projects as you create them: whoever holds it can make an identity in any group.

![New service account with a 1 year token](assets/images/step-05-service-account.jpg)

![The Massdriver Service Account form](assets/images/step-05-massdriver-service-account.jpg)

### 6. AWS Account and Networking

Every project from here on is built the same way:

1. **Projects → Create Project**: a name and a short identifier.
2. On the project, **Create Environment**: a name and identifier.
3. Open the environment's canvas. **Set environment defaults** at the top picks the shared resources every bundle in it connects to.
4. The cube at the top left opens the bundle list; drag a bundle onto the canvas and give it a name and identifier.
5. Open the component, **Config → Config options**, and pick a preset. Change what the step says, then deploy from the button at the bottom.

![Create Project](assets/images/step-06-create-project.jpg)

![Add an environment](assets/images/step-06-create-environment.jpg)

![Add a bundle to the canvas](assets/images/step-06-add-component.jpg)

![Config options: fill the form from a preset](assets/images/step-06-presets.jpg)

Create project **AWS Account** (`aws`) with environment **Workshop** (`workshop`). Set the AWS IAM Role as the environment's credential default.

Add **Budget Guard** with the **Free Tier** preset ($25 limit, alerts at 50/80/100% and on forecast), and put your address in **Email alerts to**. **Budget Guard: $0** (the first two budgets in an account are free). Confirm the subscription email AWS sends, or alerts won't arrive.

Add **Cost Reports** with the **Member account** preset (**Management account** if this is the payer account). **Cents.** When it's deployed, open its operator guide, run the command it shows, and paste the four values into **Settings → Integrations → AWS Cost and Usage Reports**. Every instance then shows its cost, usually within a day.

![The AWS Account canvas](assets/images/step-06-aws-account-canvas.jpg)

Every bundle has a **Monthly budget (USD)**; each preset fills in one. That's what the cost agent in step 11 checks against.

Create project **Networking** (`networking`) with environment **Shared** (`shared`). Set the AWS IAM Role as the environment's credential default.

Add **Shared VPC** with the **Development** preset: two zones, a NAT instance (~$7) and 7-day flow logs. Plus the flow-log encryption key, ~$1. **Shared VPC: ~$8–9.** When it's deployed, **Share** its **network** resource with all environments; every other project runs inside it.

![The Networking canvas](assets/images/step-06-networking-canvas.jpg)

![An environment's defaults](assets/images/step-06-environment-defaults.jpg)

### 7. AI Platform and CI Platform

Create project **AI Platform** (`ai`) with environment **Main** (`main`). Set the AWS IAM Role and the Shared VPC as the environment's defaults.

Add **LLM Gateway** with the **Development** preset: Kimi K2.5 (~$0.60 in / $3 out per million tokens), 1-day logs, and a $20 monthly budget per consumer that caps each sandbox, agent, runner and function.

The gateway is a small t4g.small proxy, not a model: it forwards each request to Bedrock or to your own GPU. **Gateway: ~$14 plus tokens.** When it's deployed, **Share** its **endpoint** resource with all environments.

![The LLM Gateway form](assets/images/step-07-llm-gateway.jpg)

Kimi K3 is stronger, at ~$3.30 / $16.50 per million tokens, but its multi-turn calls through Bedrock can fail on reasoning content, which is how opencode talks. Leave it for later.

> [!WARNING]
> **Optional, and not recommended for the workshop.** The GPU costs ~$0.80 an hour while it runs (~$3 for the workshop) and ~$600 a month if it never stops. Everything in the workshop works on Bedrock without it. Add it only if you mean to, and tear it down after.

Optional, the "your own model" moment (needs G/VT quota): add **vLLM Model Server** to the AI Platform with the **Development** preset (g6.xlarge with gpt-oss-20b, ~$0.80 per hour running, stops after an hour idle and at 8 pm), set **Time zone for the nightly stop** to yours, and connect it to the gateway on the canvas.

Stopped, it costs its disk and key, ~$10. **A 3-hour workshop: ~$3.** It answers about 10 minutes after its deploy finishes, so deploy it before the sandbox. Once connected, the gateway also serves `self-hosted-gpt-oss-20b`.

![The AI Platform canvas: the vLLM Model Server linked to the gateway](assets/images/step-07-ai-platform-canvas.jpg)

Create project **CI Platform** (`ci`) with environment **Main** (`main`), one per GitHub organization. Set the AWS IAM Role, the Shared VPC, the GitHub App and the LLM Gateway's endpoint as the environment's defaults. The gateway lives in another project, so the runners get it as a default, not a link.

Add **GitHub Actions OIDC** with the **New account** preset (**Provider already exists** if the account has one). It exists once per AWS account and lets GitHub Actions push images with no stored AWS keys. **$0.** **Share** its resource with all environments.

Add **GitHub Actions Runners**, named e.g. **Factory Runners**, with the **Development** preset: one Small runner (~$12) with a 30 GB disk (~$2.40).

Plus the token function, schedule and secret: under $1. **Runners: ~$15; ~$0.06 for the workshop.** They sit in the VPC's private subnets, take one job each, and reach the gateway with their own key. Jobs never get the VM's AWS role.

![The Factory Runners form](assets/images/step-07-runners.jpg)

![The CI Platform canvas](assets/images/step-07-ci-platform-canvas.jpg)

### 8. Codebases

Create project **Codebases** (`codebases`) with one environment per app, named after the app's project, e.g. **Todo App** (`todoapp`). Set the AWS IAM Role, the GitHub App, the GitHub Actions OIDC resource and the Massdriver Service Account as the environment's defaults.

Add **ECR Repository** with the **Development** preset (immutable tags, scan on push, keep 10 images: pennies), and **GitHub Repository** with the **Private app** preset (repository `todoapp`). Connect the ECR Repository to the GitHub Repository.

The repository arrives with a starter app and a pipeline: every pull request runs tests, a secret scan, an arm64 image build and an image scan; every push to `main` also pushes the image to ECR, tagged with the commit. It also gets the factory workflows (the issue agent and AI review) and an `agent` label, which run on the CI Platform's runners. Starter files are written once and then belong to the team; redeploys never overwrite them. **Codebases: ~$0** (a private build uses a few of the free plan's 2,000 Actions minutes). When it's deployed, **Share** the repository's resource with all environments.

Watch the first build under the repository's **Actions** tab. When it's green, the image URI is in ECR: `<account>.dkr.ecr.us-east-1.amazonaws.com/codebases-todoapp-ecr:<commit>`.

![The Codebases canvas: the ECR Repository linked to the GitHub Repository](assets/images/step-08-codebases-canvas.jpg)

![The GitHub Repository form](assets/images/step-08-github-repo.jpg)

### 9. Your app

Create a project named after the app, e.g. **Todo App** (`todoapp`), with environment **Dev** (`dev`). Set the AWS IAM Role, the Shared VPC, the LLM Gateway's endpoint and the GitHub App as the environment's defaults.

Add these, then connect the API and the table to the function:

| Bundle | Preset | Then change | Cost |
|---|---|---|---|
| Static Site | Single-page app | — | $0 in CloudFront's free tier |
| HTTP API | Development | — | ~$1 per million requests |
| DynamoDB Table | Development | — | ~$1.25 per million writes, $0.25 per million reads |
| Lambda Function | Free Tier | **Container image**: the image URI from step 8 | $0 in Lambda's free tier |

With the environment's LLM endpoint default set, the function also runs inside the VPC with its own gateway key, and gets `OPENAI_BASE_URL`, `OPENAI_API_KEY` and `OPENAI_MODEL`. **App: effectively $0** at workshop traffic; the free tiers cover it.

Open the HTTP API's endpoint in a browser: the app answers.

Now add sign-in. Add **User Pool** (**Users**) with the **Free Tier** preset, set **Where to return after sign-in** to the Static Site's URL with its trailing slash, and connect it to the **HTTP API**. **$0** (free for the first 10,000 monthly users). Until now the function's routes have been public: **Require sign-in** is on in its preset, but there was no user pool yet, and its deploy log said so. Redeploy the HTTP API, then redeploy the function. The endpoint now answers `401` without a signed-in user's token.

Add **Alarm to Issue** with the **Issues only** preset and turn on **Send a test alarm on this deploy** for the first deploy only. Point its **repository** at the Codebases repository with a remote reference. **$0.** The test deploy opens an `Alarm: …` issue in the repository, with links to the alarm and the Massdriver project, environment and instance it came from.

![The Todo App canvas](assets/images/step-09-todo-app-canvas.jpg)

### 10. The factory, live

All in the browser.

1. **Check the agents are there.** The `todoapp` repository already has `.github/workflows/agent.yml`, `.github/workflows/ai-review.yml` and an `agent` label, from the factory workflows in step 8.
2. **Turn on release to dev.** Merged code should reach dev without anyone touching Massdriver. The repository gets its own Massdriver identity for that, made by the identity maker from step 5. On the **GitHub Repository**, set **Release to** to the Lambda Function's instance ID, e.g. `todoapp-dev-fn`, pick your release group in **Release permissions**, and deploy. The repository gets a `release` workflow and a service account in that group only.

![Release to and Release permissions on the GitHub Repository](assets/images/step-10-release-to.jpg)
3. **Issue → pull request.** Open an issue, e.g. "Add a `/health` route that returns `{"ok": true}`, with a test", and label it `agent`. Within a few minutes the agent comments, then opens a pull request from `agent/issue-N`.

![An issue labeled agent](assets/images/step-10-issue.jpg)

![The agent's pull request](assets/images/step-10-pull-request.jpg)
4. **CI and review run on it.** The tests, secret scan, build and image scan run, and the gateway's model posts a review. If the review has a point, comment `/agent` with it, and the agent updates the same pull request.
5. **Merge it.** The push to `main` builds a new image and pushes it to ECR. When the build is green, the `release` workflow deploys it to the Lambda Function in dev. Watch the deployment appear on the Lambda Function in Massdriver with the message `Release <commit>`. That deployment is the proof: every route, `/health` included, answers `401` without a signed-in user's token.

![Agent, AI review, build and release runs](assets/images/step-10-actions.jpg)

![The Release deployment on the Lambda Function](assets/images/step-10-release-deployment.jpg)
6. **Close the loop.** On **Alarm to Issue**, turn **Hand alarms to the agent** on and deploy. From now on, when one of the app's alarms fires, an issue opens with the `agent` label, the agent proposes a fix, CI and review run, and a person decides whether to merge.

Each agent run costs ~$0.10–0.50 in tokens on Kimi K2.5, charged to the runners' gateway key.

The software factory is done.

### 11. Agents that run themselves

> [!WARNING]
> **The agents never stop on their own.** Each agent's VM stays up: ~$31 a month each. A test run costs one run's tokens, ~$0.15. On duty, the SRE agent reads ~200,000 tokens every 10 minutes: **~$0.75 an hour**, until the gateway stops it at $20 for the month, about a day later. Remove both agents when you're done (item 6).

An agent is a prompt and a schedule. The **Agent** bundle is a VM that runs a coding agent on a schedule, with the prompt you give it, under its own Massdriver identity. The SRE agent and the cost agent are the same bundle with different presets. They read everything through Massdriver, hold no cloud credentials, and only ever propose.

1. **The project.** Create **Agents** (`agents`) with environment **Main** (`main`). Set the AWS IAM Role, the Shared VPC, the LLM Gateway's endpoint, the GitHub App and the Massdriver Service Account as its defaults. The identity maker from step 5 makes the agents' identities. One Agents project serves the whole organization: the agents work through Massdriver, so they cover every cloud account it manages.

   ![The Agents canvas](assets/images/step-11-agents-canvas.jpg)
2. **Test runs.** Add the **Agent** bundle twice. Pick the **SRE Agent: test run** preset on one and the **Cost Agent: test run** preset on the other. Pick your agent group from step 5 in **Massdriver groups** on both. Leave **AWS access** at **None**, and deploy. Each deploy creates a service account for that agent, in that group only. **~$31 each a month; ~$0.04 an hour each, plus ~$0.15 of tokens for each test run.** The gateway stops each agent at $20 a month.

   The two settings answer different questions. **Massdriver groups** decides what the agent can do to your infrastructure: with the agent group, view, plan and propose, never deploy. **AWS access** decides what it can read straight from AWS, beyond its own secrets: **None**, **Alarms, metrics, logs and resource lists** (AWS's CloudWatch read-only and view-only policies), or **Read everything, including S3 objects and table data** (ReadOnlyAccess). No level can change anything in AWS. The SRE and Cost agents need **None**: alarms, instances, costs and deployment logs all come through Massdriver.

   ![The Agent bundle's presets](assets/images/step-11-agent-presets.jpg)

   ![The SRE Agent: test run preset](assets/images/step-11-test-run-preset.jpg)

   Their schedule is **Once**: each runs its test after boot, and again whenever its prompt changes. A test pretends the trigger happened and does the rest for real. Within a few minutes, both show up in Massdriver:
   - The SRE agent pretends one of the app's alarms is firing, digs into the instance, and proposes a fix or opens a draft pull request, marked **🚨 [test]**.
   - Cost data takes a day, so the cost agent pretends one instance costs 3 times its budget. It finds a cheaper config, runs a plan marked **💸 [test]**, and proposes the change with a **💸 [test]** message.

   Open the instances they picked to see the plan and the pending proposals. Reject them, and close any draft pull request.

   ![A 🚨 [test] proposal waiting for a person: Plan, Reject or Approve](assets/images/step-11-proposal.jpg)
3. **Put them on duty (optional).** Switch each agent to its real preset, **SRE Agent** or **Cost Agent**, and deploy. The SRE agent then checks Massdriver's alarms every 10 minutes, ~$0.75 an hour in tokens. The cost agent checks every instance's cost against its budget once a day, ~$0.15 a run.

   ![The SRE Agent on duty: its prompt, schedule, groups and AWS access](assets/images/step-11-agent-config.jpg)
4. **An agent of your own (optional).** Add a third **Agent** with the **Your own** preset. Write its **Prompt** and deploy. It runs once after boot, and again whenever you change the prompt. Pick another **Schedule** to repeat it. Give it **AWS access** only if its prompt needs what Massdriver doesn't show, such as a function's own log lines (**Alarms, metrics, logs and resource lists**) or the rows in a table (**Read everything**).
5. **Watch one work (optional).** This needs a terminal.
   1. In Massdriver, open the Cost Agent's **Connect to …** resource and click **Connect script**. It downloads a `.sh` file.
   2. Install the AWS CLI and the Session Manager plugin. Homebrew's cask for the plugin is disabled, so it comes from AWS:

      ```bash
      brew install awscli
      curl -fsSLo /tmp/smp.zip "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$([ "$(uname -m)" = arm64 ] && echo mac_arm64 || echo mac)/sessionmanager-bundle.zip"
      unzip -qo /tmp/smp.zip -d /tmp
      sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
      ```

   3. `sh ~/Downloads/<connect script>`. It sets up an AWS profile and an SSH host for this agent only.
   4. `ssh agents-main-cost`. Its journal is `/workspace/cost/journal.md`, and every run's output is in `/workspace/.goal/runs`. To run its prompt right now:

      ```bash
      sandbox-goal --now
      ```

6. **Remove them.** On the **Agents** canvas, decommission **SRE Agent** and **Cost Agent**. This stops their VMs and their tokens. Their service accounts are deleted with them. Deploy them again whenever you want them back.

The SRE agent's journal is in `/workspace/sre/journal.md`. Copy anything you want to keep before item 6. To change what an agent does, edit its **Prompt** or **Schedule** and deploy.

### 12. Your sandbox

Create project **Developer Sandboxes** (`devsandboxes`) with an environment named after you, e.g. `cory`. Set the AWS IAM Role, the Shared VPC, the LLM Gateway's endpoint and the GitHub App as the environment's defaults.

Add **Developer Sandbox** with the **In the browser** preset: a Light ARM VM (~$0.03 per hour running), a 20 GB workspace (~$1.60), private network, browser access ($0 in CloudFront's free tier), opencode, and stops after 30 idle minutes and at 8 pm. Set **Timezone** and your name and email for commits.

Plus the system disk (~$1.30) and the idle alarm (~$0.10). **Sandbox: ~$3 stopped, ~$10 on workday hours. A 3-hour workshop: ~$0.15.** The first deploy with browser access takes about 15 minutes while CloudFront connects to the VM.

Private mode means no public address (saving ~$4 a month) and nothing on the internet can reach the VM; CloudFront reaches it privately. The sandbox can clone and push your organization's repositories through the GitHub App, with no personal token.

**Shell in.**

1. In Massdriver, open the sandbox's **Connect to …** resource and click **Connect script**. It downloads a `.sh` file.

   ![The sandbox's Connect to resource](assets/images/step-12-connect-resource.jpg)
2. If you skipped step 11, item 5, install the AWS CLI and the Session Manager plugin as shown there.
3. `sh ~/Downloads/<connect script>`. It sets up an AWS profile and an SSH host for this sandbox only, and prints the browser URLs with their username and password.
4. Either open the **opencode** URL in the browser, or `ssh devsandboxes-<you>-sandbox` and run `opencode`. If the sandbox has stopped itself, `ssh` starts it; give it a minute.

Inside, `git clone https://github.com/<your-org>/todoapp` works with no login. opencode starts on Kimi K2.5. `/models` switches to Kimi K3 if the gateway serves it (the **Demo** preset), or to `self-hosted-gpt-oss-20b` if you added the GPU.

### 13. Vibe code an app

You are a citizen developer now. You describe an app; the agent in your sandbox designs its infrastructure in Massdriver, writes the code, and ships it to dev. Anything outside dev, it can only propose.

> [!WARNING]
> **A long agent session reads a few million tokens: ~$1–3 on Kimi K2.5.** It's charged to your sandbox's gateway key, which stops at $20 a month. The app it builds runs in its free tiers, like step 9.
>
> **Stay on Kimi K2.5.** Kimi K3 costs ~5.5× as much. Three vibe-coded apps on K3 burned ~$20 of tokens in rehearsal, a whole Development cap.

1. **Give your sandbox an identity.** Set the **Massdriver Service Account** credential as a default on your **Developer Sandboxes** environment. On your sandbox from step 12, pick your builder group from step 5 in **Massdriver access for agents** and deploy. The sandbox gets its own service account, in that group only.
2. **A project for the app.** Create **Notes** (`notes`) with environment **Dev** (`dev`). Set the AWS IAM Role, the Shared VPC, the LLM Gateway's endpoint and the GitHub App as its defaults. Leave the canvas empty.
3. **Vibe code it.** Shell in to your sandbox as in step 12, `mkdir notes && cd notes`, and run `opencode`. Tell it what you want, e.g. "A notes app with sign-in. Use the Massdriver architect to build it in the `notes` project as an application on the lambda-function runtime, with its own tables. Put its GitHub repository and ECR repository in a Codebases environment named `notes`. Deploy it to dev, then write the app in that repository and open a pull request." Steer it as it goes.
4. **Ship it.** The architect adds the Codebases environment and the **Notes** canvas, and deploys them; watch them appear. The app's tables are linked to the app on the canvas. When the app exists, set **Release to** on the `notes` repository to its instance ID with your release group picked, as in step 10. Merge the pull request, and the `release` workflow ships it.

Linkly (`applications/linkly`) is an app built this way: a link shortener whose `massdriver.yaml` names its two tables and the envs that carry them. It serves its landing page at `/` and its API under `/api`, so its canvas has no Static Site.

![Linkly's canvas: its two tables and the API wired to the app](assets/images/step-13-linkly-canvas.jpg)

The sandbox runs as you designed it: it can build and deploy in dev, and nothing else. Try asking it to deploy to production; it can only propose.

### 14. Tear it down

> [!WARNING]
> **Tear everything down before you leave.** Stopped machines still bill for their disks, including a stopped GPU (~$10 a month). The gateway, NAT instance and factory runner never stop on their own (~$38 a month together), and neither do the agents (~$31 a month each, plus tokens). Decommissioning deletes everything, disks included.

Decommission each environment in this order; the shared pieces go last because everything else runs on them:

1. **Agents** (`main`). Their service accounts are deleted with them.
2. **Your apps** (`todoapp` / `dev` and `notes` / `dev`)
3. **Developer Sandboxes** (your environment). Anything in `/workspace` that isn't pushed to git is gone.
4. **Codebases** (`todoapp` and `notes`). The GitHub repository is archived, not deleted; its images are deleted.
5. **CI Platform** (`main`): the runners and GitHub Actions OIDC.
6. **AI Platform** (`main`): the gateway, and the GPU if you added it.
7. **Networking** (`shared`): the VPC and its NAT instance.
8. **AWS Account** (`workshop`): Budget Guard and Cost Reports. Then remove the **AWS Cost and Usage Reports** integration in **Settings → Integrations**; its bucket is gone.

Then delete the IAM role from step 3 and the GitHub App from step 4 if you won't use them again. In Massdriver, delete the identity maker's service account and credential from step 5; it can make an identity in any group.

## Appendix

### Identities and secrets

Every arrow in the diagrams runs as one of these. Nothing shares a personal token.

| What | Made by | Lives in | Used by, for | Scope |
|---|---|---|---|---|
| **AWS IAM Role** credential | You, step 3 | Massdriver, default on every environment | Massdriver, to deploy every bundle | Your account, with your External ID |
| **GitHub App** credential | You, step 4 | Massdriver, default on CI Platform, Agents, Codebases, Developer Sandboxes and each app | The bundles below, to manage repositories and mint short tokens | The repositories the App is installed on |
| **GitHub Actions OIDC** resource | GitHub Actions OIDC bundle, step 7 | An IAM OIDC provider; shared resource | Repository push roles, to trust GitHub's tokens | One per AWS account |
| Push role `<repo>-push` | GitHub Repository bundle | IAM; Actions variables `AWS_ROLE_ARN`, `AWS_REGION`, `ECR_REPOSITORY_URL` | The `build` workflow, to push images | The default branch of that one repository; push to its ECR repository only |
| GitHub App key copy | Runners, Developer Sandbox, Agent and Alarm to Issue bundles | Secrets Manager, `<instance>/github-app` | Runners: register and mint agent tokens. Sandbox and Agent: `git` and `gh`. Alarm to Issue: open issues | Readable only by that instance's role |
| Agent token | The runners' token function, per job | Memory of one job | `agent.yml`, to push a branch and open a pull request | One repository, `contents`, `pull_requests`, `issues`; only `agent.yml` on issue events; about an hour |
| Gateway master key | LLM Gateway bundle | Secrets Manager, `<gateway>/master-key` | Admin of the gateway | Everything on the gateway |
| Gateway consumer key | Runners, Developer Sandbox, Agent and Lambda Function bundles, one each | SSM, under the gateway's key prefix | That consumer, to call models | $20 a month per consumer by default |
| Model server key | vLLM Model Server bundle | Secrets Manager | The gateway, to call your GPU | That model server |
| Identity-maker group, e.g. **Service Account Managers** | You, step 5 | Massdriver | Holds the identity maker | `manageServiceAccounts`, `manageGroups`: equal to Organization Admin |
| Identity maker and **Massdriver Service Account** credential | You, step 5 | Massdriver, shared with the Codebases, Developer Sandboxes and Agents projects | Repository, sandbox and agent bundles, to make their own service accounts | Can make an identity in any group. Delete it at teardown |
| Release group, e.g. **Release to Dev** | You, step 5 | Massdriver | Release service accounts | `project:view`, `instance:deploy` where `md-environment` is `dev` |
| Release service account `<org>/<repo> release` | GitHub Repository bundle, when **Release to** is set | Token in the Actions secret `MASSDRIVER_API_KEY`; variables `MASSDRIVER_ORGANIZATION_ID`, `MASSDRIVER_URL`, `MASSDRIVER_RELEASE_INSTANCE` | The `release` workflow, to deploy the new image | The groups picked in **Release permissions**; one-year token |
| Agent group, e.g. **Factory Agents** | You, step 5 | Massdriver | Agent service accounts | `project:view`, `instance:plan`, `instance:propose`; no deploy |
| Builder group, e.g. **Citizen Developers** | You, step 5 | Massdriver | Your sandbox's service account | Create and design projects, plan and propose anywhere; configure, deploy and decommission only where `md-environment` is `dev`, and in every Codebases environment, where its apps' repositories live |
| Sandbox service account, named after the instance | Developer Sandbox bundle, when groups are picked | Secrets Manager, `<instance>/massdriver-api-key` | `mass` and the Massdriver MCP in your sandbox | The groups picked in **Massdriver access for agents**; one-year token |
| Agent service account, named after the instance | Agent bundle, when groups are picked | Secrets Manager, `<instance>/massdriver-api-key` | `mass` and the Massdriver MCP in the agent's runs | The groups picked in **Massdriver groups**; one-year token |
| Agent's AWS role | Agent bundle | IAM, on the agent's VM | The agent's runs, to read AWS directly | Its own secrets, plus what **AWS access** adds: nothing, CloudWatch and view-only, or ReadOnlyAccess. Read-only at every level |
| Access user `<instance>-access` | Developer Sandbox and Agent bundles | The **Connect to …** resource; an AWS profile on your laptop after the connect script | `ssh`, to start the VM and open a session | Start that VM and connect as `dev` |
| Browser password | Developer Sandbox bundle | Secrets Manager, `<instance>/browser-password`; printed by the connect script | You, for opencode in the browser and the preview URL | That sandbox |
| Cost collector user | Cost Reports bundle | IAM; keys in Secrets Manager, `<instance>/integration` | Massdriver's cost integration, after you paste them in step 6 | Read the cost report bucket and resource tags |

### What it costs (us-east-1, on-demand, approximate)

| Step | Workshop (~3 hours) | A month if left running | What stops it |
|---|---|---|---|
| Optional shortcut: `bootstrap/` + `deploy.sh` (builds steps 5–9, release to dev and step 11, no GPU) | ~$0.13 an hour (~$0.05 without the agents), plus ~$0.75 an hour of SRE agent tokens | ~$100 with the agents, ~$38 without | Nothing; step 14 |
| 6. AWS Account: Budget Guard, Cost Reports | ~$0 | Cents | Step 14 |
| 6. Networking: Shared VPC | ~$0.05 | ~$9 | Nothing; step 14 |
| 7. AI Platform: LLM Gateway | ~$0.06 | ~$14 | Nothing; step 14 |
| 7. CI Platform: Factory Runners | ~$0.06 | ~$15 | Nothing; step 14 |
| ⚠️ 7. AI Platform: vLLM Model Server (optional, **not recommended**) | ~$2.50–3 | ~$10 stopped, ~$150 on workday hours, ~$600 always on | Idle stop (1 hour), nightly stop (8 pm), step 14 |
| 8. Codebases | ~$0 | Cents | Step 14 |
| 9. Your app | ~$0 | ~$0 at low traffic | Step 14 |
| 10, 12. Factory agent runs and opencode (tokens) | ~$0.50–1.50 | Up to $20 per consumer | The gateway's $20 per consumer per month |
| ⚠️ 11. SRE Agent and Cost Agent VMs (Agent bundle) | ~$0.25 | ~$62 (always on) | Nothing; remove them after their tests, or step 14 |
| ⚠️ 11. SRE Agent tokens | ~$0.15 for the test run; ~$0.75 an hour on duty | $20 on duty, reached in about a day | The gateway's $20 cap; remove the agent |
| 11. Cost Agent tokens | ~$0.15 a run | ~$5 on duty (one run a day) | The gateway's $20 cap |
| 12. Your sandbox | ~$0.15 | ~$3 stopped, ~$10 on workday hours | Idle stop (30 minutes), nightly stop (8 pm), step 14 |
| ⚠️ 13. Vibe coding (tokens) | ~$1–3 | Up to $20 | The gateway's $20 cap on your sandbox |

| Scenario | Bedrock (default) | Plus your own GPU |
|---|---|---|
| The workshop, agents removed after their tests, then teardown | ~$3–5 | ~$6–8 |
| The workshop with the SRE agent on duty all 3 hours | ~$7–9 | ~$10–12 |
| A month of solo development, everything auto-stopping, no agents | ~$60–90 | ~$210–240 |
| A month left running 24×7, agents included | ~$125 plus up to $20 of tokens per consumer | ~$725+ |

Where the money goes in a month: the pieces that never stop (VPC ~$9, gateway ~$14, one factory runner ~$15, ~$31 per agent), the sandbox (~$3 stopped, ~$10 on workday hours), and tokens. One agent run on Kimi K2.5 reads ~200,000 tokens: ~$0.10–0.20. The gateway stops each consumer (each sandbox, agent, runner and function) at $20 a month by default. New-account AWS credits cover the workshop.

### Costs in detail

us-east-1 on-demand prices, for the presets this walkthrough uses.

#### Unit prices used

| Item | Price |
|---|---|
| t4g.nano (NAT instance) | $0.0042/h, $3.07/mo |
| t4g.small (gateway, Small runner) | $0.0168/h, $12.26/mo |
| t4g.medium (sandbox Light, agents, Medium runner) | $0.0336/h, $24.53/mo |
| t4g.large (sandbox Standard, the Demo preset) | $0.0672/h, $49.06/mo |
| g6.xlarge (vLLM) | $0.8048/h, ~$587/mo |
| gp3 disk | $0.08/GB-mo |
| Public IPv4 | $0.005/h, $3.65/mo |
| KMS key | $1/mo |
| CloudWatch alarm | $0.10/mo |
| Kimi K2.5 on Bedrock | $0.60 in / $3.00 out per M tokens |
| Kimi K3 on Bedrock | $3.30 in / $16.50 out per M tokens |

#### Measured token use

Measured on a running SRE Agent: ~217K tokens per run, **~$0.13–0.15 per agent run** on Kimi K2.5. Runs every 10 minutes come to 6 an hour, **~$0.75–0.90 an hour**.

The issue agent, AI review and vibe-coding figures are estimates scaled from this.

#### Totals

- **Workshop, agents removed after their tests:** ~$3–5 on Bedrock, ~$6–8 with the GPU.
- **Workshop with the SRE agent on duty all 3 hours:** ~$7–9.
- **A month left running 24×7 without the GPU:** ~$125, plus up to $20 per gateway consumer. That's about 6 consumers (runners, sandbox, two functions, two agents), so up to ~$120 of tokens.

#### Biggest risks

1. **The SRE agent burns tokens fast on duty.** Every 10 minutes it reads ~200K tokens: ~$0.75 an hour, ~$18 a day. The per-consumer cap ($20 on Development) stops it in about a day, and after that it silently does nothing for the rest of the month. To slow it, pick a longer **Schedule** on the instance. Remove both agents when you're done (step 11, item 6).
2. **A forgotten GPU.** ~$0.80 an hour and ~$600 a month if it never stops. The Development preset idles out after an hour and stops at 8 pm, but a stopped GPU still bills ~$10 a month for its disk. It also needs G/VT quota that most new accounts lack. Skip it for the workshop.
3. **Forgotten teardown.** The VPC, gateway and runners never stop (~$38 a month). Agents never stop (~$31 a month each). Token caps stack per consumer. A stopped sandbox still bills ~$3 a month for its disks.
4. **Token caps run on the gateway's own estimates.** The real bill is in Cost Explorer. Bedrock bills per token with no minimum, so nothing bills after teardown.
5. **Kimi K3 is ~5.5× K2.5.** The Demo gateway preset enables it. A K3 session costs ~5.5× as much, and its multi-turn calls can fail through Bedrock. ⚠️ Three vibe-coded apps on K3 burned ~$20 of tokens in rehearsal. Keep K2.5 as the default model.

#### The Demo presets, per day

| Piece | Demo settings | Per day |
|---|---|---|
| VPC | Development | ~$0.30 |
| Gateway | K2.5 + K3, $50 cap per consumer | ~$0.46 |
| Runners | 2× t4g.medium, 30 GB | ~$1.77 |
| vLLM | never idles out, stops at 10 pm | ~$11.60 if started at 8 am (14 h × $0.80 + disk) |
| Sandbox | t4g.large, never idles out, stops at midnight | ~$1.85 if up all day |
| SRE Agent VM | SRE Agent preset, t4g.medium, 24×7 | ~$1.05 |
| Cost Agent VM | Cost Agent preset, t4g.medium, 24×7 | ~$1.05 |
| SRE Agent tokens | every 10 min | ~$18 until it reaches its $50 cap (~2.8 days) |
| Cost Agent tokens | daily | ~$0.15 |
| App, Codebases, Cost Reports | | ~$0 |

**~$18 a day in infrastructure, ~$6.50 of it without the GPU, plus up to ~$18 a day of SRE Agent tokens.**
