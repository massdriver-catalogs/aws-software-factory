# Workshop notes

Building a Citizen Developer Agentic Software Factory on Self-Hosted Models in Your Own VM Sandbox in Under an Hour

Free workshop paired with the Product Hunt launch of the Massdriver Architect / Context Engine. The catalog in this repo is the product; the workshop is one path through it.

## Scope

Everything runs live; nothing is take-home. The factory is the point of the workshop.

1. **Foundation:** network, AI Platform, a developer sandbox.
2. **An app:** repository, image repository, API, function, table.
3. **The factory:** runners in the account, an issue that an agent turns into a pull request, AI review on that pull request, a merge that deploys to dev, and a production alarm that opens the next issue.

## Attendee prerequisites (registration email, not day-of)

- **AWS account.** For the self-hosted GPU, request "Running On-Demand G and VT instances" quota of 4+ vCPUs about a week ahead; new accounts often start at 0. No quota → Bedrock only.
- **Massdriver account.**
- **GitHub organization.** A free one is fine. GitHub Apps can't create repositories under a personal account.

Then, before the workshop, connect both to Massdriver:

### Connect AWS (~5 minutes)

Massdriver deploys into your account by assuming a role you create. The role trusts Massdriver's AWS account only when your organization's external ID is presented.

1. In Massdriver: **Credentials → Add → AWS IAM Role**. Keep this tab open; the instructions on it show your **External ID**.
2. In the AWS Console: **IAM → Roles → Create role**.
3. Choose **AWS account → Another AWS account** and enter `308878630280`.
4. Tick **Require external ID** and paste the External ID from step 1. **Next**.
5. Search for and tick **AdministratorAccess**. The catalog creates networks, IAM roles, GPU instances and model endpoints. **Next**.
6. Name the role `massdriver` and **Create role**.
7. Open the role, copy its **ARN** from the top of the page, and paste it and the External ID into the Massdriver form. **Save**.

For Kimi and other Bedrock models, nothing else is needed: Bedrock's open-weight models are enabled by default.

### Connect GitHub (~10 minutes)

Massdriver creates repositories, workflows and runners through a GitHub App on your organization. The app's tokens expire within an hour, and it acts as a bot, not as you.

1. Go to **github.com/organizations/<your-org>/settings/apps/new**.
2. **GitHub App name:** `<your-org>-massdriver`. **Homepage URL:** your organization's GitHub URL. Under **Webhook**, untick **Active**.
3. **Repository permissions**, all **Read and write**: Administration, Contents, Workflows, Actions, Secrets, Variables, Issues, Pull requests. (Metadata becomes Read-only on its own.)
4. **Organization permissions:** Self-hosted runners → **Read and write**.
5. **Where can this GitHub App be installed?** → **Only on this account**. **Create GitHub App**.
6. On the app's page, copy the **App ID**.
7. Under **Private keys**, **Generate a private key**. A `.pem` file downloads.
8. **Install App** in the sidebar → your organization → **All repositories** → **Install**. The URL ends in `/installations/<number>`: that number is the **Installation ID**.
9. In Massdriver: **Credentials → Add → GitHub App**. Fill in your organization's login, the App ID, the Installation ID, and the whole contents of the `.pem` file. **Save**.

## Cost talking points (us-east-1, on-demand, approximate)

| Scenario | Bedrock | Self-hosted GPU |
|---|---|---|
| Workshop (~3h, then teardown) | ~$0.50 | ~$3 |
| Solo dev month, auto-stop on | ~$30–60 | ~$165 |
| Left on 24×7 | ~$120 | ~$650+ |

New-account AWS credits cover the Bedrock path. Forgetting a GPU is the main risk; auto-stop and the budget alarm exist for it.

## Steps

Costs are approximate, per month, us-east-1. Every pick is the cheapest option that doesn't hurt the experience.

### 1. Check your credentials

Both credentials from the prerequisites show under **Credentials**: an AWS IAM Role and a GitHub App. — $0

### 2. Networking

Create project **Networking** (`networking`) with environment **Dev** (`dev`). Add **Shared VPC**.

| Field | Pick | Cost |
|---|---|---|
| Region | us-east-1 | — |
| CIDR | 10.0.0.0/16 | — |
| Availability zones | 2 | — |
| Internet egress for private subnets | NAT instance | ~$7 |
| Interface endpoints | none | $0 (each adds ~$7 per zone) |
| Flow log retention | 7 days | <$1 at workshop traffic |

Always on: flow log encryption key ~$1. **Shared VPC total: ~$8–9/month.**

### 3. AI Platform

Create project **AI Platform** (`aiplatform`) with environment **Dev** (`dev`). Set the Shared VPC as the environment's network default.

Add **LLM Gateway**:

| Field | Pick | Cost |
|---|---|---|
| Bedrock models | Kimi K2.5 | ~$0.60 in / $3 out per M tokens; a heavy agent session is roughly $1–2 |
| Log retention | 1 day | <$1 |

Always on: t4g.small gateway, disk, and the admin key secret. **Gateway total: ~$14/month plus tokens.** Kimi K3 is stronger at ~$3.30 / $16.50 per M tokens, but its multi-turn calls through Bedrock's Converse API can fail with reasoning content, which is how opencode talks.

Optional, for "your own GPU" (needs G/VT quota): add **vLLM Model Server** and connect it to the gateway.

| Field | Pick | Cost |
|---|---|---|
| GPU | g6.xlarge | ~$0.80 per hour running |
| Model | gpt-oss-20b | — |
| Stop when idle for | 1 hour | — |
| Stop every night at | 8 pm, your time zone | — |
| Log retention | 1 day | <$1 |

Stopped, it costs its disk and key (~$10/month). **A 3-hour workshop: ~$3.** It answers about 10 minutes after the deploy finishes (image and model download), so start it before the sandbox step.

### 4. Developer Sandboxes

Create project **Developer Sandboxes** (`devsandboxes`) with one environment per person, named after them (e.g. `cory`). Set the Shared VPC as the network default and the AI Platform's LLM endpoint as the model default.

Add **Developer Sandbox**:

| Field | Pick | Cost |
|---|---|---|
| Size | Light | ~$0.03 per hour running |
| Chip | ARM | — |
| Workspace disk | 20 GB | ~$1.60 |
| Network | Public IP, no inbound | ~$0.005 per hour running; no NAT needed |
| Stop when idle for | 30 minutes | — |
| Stop every night at | 8 pm, your time zone | — |
| Coding agents | opencode | — |
| How much do agents do on their own? | Run freely inside the sandbox | — |
| Languages | Python, Node.js | — |

Always on: the 16 GB system disk (~$1.30) and the idle alarm (~$0.10). **Sandbox total: ~$3/month stopped, ~$10/month on workday hours, ~$31 if never stopped. A 3-hour workshop: ~$0.15.**

Connect from your own terminal (no AWS login):

1. Install the AWS CLI and the Session Manager plugin (Homebrew's cask for the plugin is disabled):

   ```bash
   brew install awscli
   curl -fsSLo /tmp/smp.zip "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$([ "$(uname -m)" = arm64 ] && echo mac_arm64 || echo mac)/sessionmanager-bundle.zip"
   unzip -qo /tmp/smp.zip -d /tmp
   sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
   ```
2. In Massdriver, open the sandbox's **Connect to …** resource → **Connect script**, then `sh ~/Downloads/<file>`
3. `ssh devsandboxes-<you>-sandbox`, then `opencode`

### 5. Your app

Create a project named after the app (e.g. **Todo App**, `todoapp`) with environment **Dev** (`dev`). Add **HTTP API**, **DynamoDB Table** and **Lambda Function**; connect the API and the table to the function.

| Bundle | Field | Pick | Cost |
|---|---|---|---|
| HTTP API | Steady / burst requests | 50 / 100 | ~$1 per million requests |
| HTTP API | Access log retention | 1 day | <$0.10 |
| DynamoDB Table | Keys | `pk` / `sk`, String | — |
| DynamoDB Table | Point-in-time recovery | off | $0 |
| DynamoDB Table | Table class | Standard | ~$1.25 per million writes, $0.25 per million reads, $0.25/GB-month |
| Lambda Function | Container image | empty (placeholder) | — |
| Lambda Function | Memory | 256 MB | ~$0.000004 per 1-second request |
| Lambda Function | Log retention | 1 day | <$0.10 |

**App total at workshop traffic: effectively $0** (Lambda, API Gateway and DynamoDB free tiers cover it). Open the HTTP API's endpoint in a browser: the placeholder answers with the request and the table's status.

### 6. Tear it down

> [!WARNING]
> **Tear everything down before you leave.** Stopped machines still bill for their disks, and the gateway and NAT instance never stop on their own (~$21/month together). Decommissioning deletes everything, disks included.

Decommission each environment in this order; the shared pieces go last because everything else runs on them:

1. **Your app** (`todoapp` / `dev`)
2. **Developer Sandboxes** (your environment). Anything in `/workspace` that isn't pushed to git is gone.
3. **AI Platform** (`dev`)
4. **Networking** (`dev`)

Then delete the IAM role you created in step 1 if you won't use Massdriver with this account again.

## Messaging

- A 20B model on one L4 is a working coding agent, not a frontier model. Show the one-setting switch to a bigger Bedrock model.
- The agent never holds cloud credentials; infra changes go through Massdriver.
- "Production alarm → issue → agent PR → approved deploy" is the closing demo.
