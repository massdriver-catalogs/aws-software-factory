# Workshop notes

Building a Citizen Developer Agentic Software Factory on Self-Hosted Models in Your Own VM Sandbox in Under an Hour

Free workshop paired with the Product Hunt launch of the Massdriver Architect / Context Engine. The catalog in this repo is the product; the workshop is one path through it.

## Scope

- Live: catalog phases 1–4 (foundation, model, sandbox, browser access) plus one app from phase 5.
- Finale or take-home: phase 6–7 (factory runners, issue → PR, alarm → issue).

## Attendee prerequisites (registration email, not day-of)

- AWS account. Request "Running On-Demand G and VT instances" quota of 4+ vCPUs about a week ahead; new accounts often start at 0. No quota → Bedrock path.
- Massdriver account with the AWS role connected.
- GitHub account.

## Cost talking points (us-east-1, on-demand, approximate)

| Scenario | Bedrock | Self-hosted GPU |
|---|---|---|
| Workshop (~3h, then teardown) | ~$0.50 | ~$3 |
| Solo dev month, auto-stop on | ~$30–60 | ~$165 |
| Left on 24×7 | ~$120 | ~$650+ |

New-account AWS credits cover the Bedrock path. Forgetting a GPU is the main risk; auto-stop and the budget alarm exist for it.

## Steps

Costs are approximate, per month, us-east-1. Every pick is the cheapest option that doesn't hurt the experience.

### 1. Connect AWS

Credentials → AWS IAM Role, follow the AWS Console instructions. — $0

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

Stopped, it costs its disk and key (~$10/month). **A 3-hour workshop: ~$3.**

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

1. `brew install awscli && brew install --cask session-manager-plugin`
2. In Massdriver, open the sandbox's **Connect to …** resource → **Connect script**, then `sh ~/Downloads/<file>`
3. `ssh devsandboxes-<you>-sandbox`, then `opencode`

## Messaging

- A 20B model on one L4 is a working coding agent, not a frontier model. Show the one-setting switch to a bigger Bedrock model.
- The agent never holds cloud credentials; infra changes go through Massdriver.
- "Production alarm → issue → agent PR → approved deploy" is the closing demo.
