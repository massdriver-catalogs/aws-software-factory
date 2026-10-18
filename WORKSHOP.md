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

## Messaging

- A 20B model on one L4 is a working coding agent, not a frontier model. Show the one-setting switch to a bigger Bedrock model.
- The agent never holds cloud credentials; infra changes go through Massdriver.
- "Production alarm → issue → agent PR → approved deploy" is the closing demo.
