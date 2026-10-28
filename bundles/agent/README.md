# Agent

A VM that runs a coding agent on a schedule, with a prompt you give it at deploy. Nobody drives it. It gets its own Massdriver identity in the groups you pick, and it can do only what those groups allow.

An agent is a prompt and a schedule. The SRE agent and the cost agent are both this bundle with a different preset.

## What's on it

- The chosen coding agent, opencode or Claude Code, configured for the AI Platform when an LLM endpoint is connected
- Massdriver tooling: the `mass` CLI and the Massdriver MCP server, once it has a Massdriver key
- `git` and `gh` against the GitHub App's organization, with no personal token
- `dev` user, docker, mise with the chosen languages

Work goes in `/workspace`. It's a separate disk that survives the VM being rebuilt.

## Params

| Param | What it does |
|---|---|
| **Prompt** (`prompt`) | The standing goal. Read on every run, so changing it never rebuilds the VM |
| **Schedule** (`schedule`) | `once`, `5m`, `10m`, `15m`, `1h`, `6h` or `1d`. **Once** runs after boot and again whenever the prompt changes |
| **Agent CLI** (`cli`) | `opencode` or `claude-code` |
| **Massdriver groups** (`massdriver_groups`) | The agent gets its own service account in these groups. Needs a Massdriver Service Account credential on the environment |
| **AWS access** (`aws_access`) | None, alarms/metrics/logs/resource lists, or read everything. It can never change anything |
| **Size**, **Chip**, **Workspace disk**, **Network**, **Languages** | The VM |
| **Monthly budget (USD)** | What the instance should cost in a month |

The VM runs around the clock, whatever the schedule. Each run's output goes to `/workspace/.goal/runs`, and the last 100 are kept. Runs stop after 2 hours and never overlap.

## Connections

| Connection | Needed for |
|---|---|
| AWS IAM Role | Deploying the VM |
| Network | Where the VM runs |
| LLM endpoint | The model. Without it the agent is installed but has nothing to call |
| GitHub App | Cloning repositories and opening pull requests |
| Massdriver Service Account | Making the agent's own identity |

Set them as environment defaults; nothing is linked on the canvas.

## Presets

| Preset | Schedule | What it does |
|---|---|---|
| **Your own** | Once | A blank **Prompt** for you to write |
| **SRE Agent: test run** | Once | Pretends an alarm is firing and does the rest for real, marked **🚨 [test]** |
| **SRE Agent** | Every 10 minutes | Finds firing alarms through Massdriver. A config problem becomes a 🚨 proposed deployment; a code problem becomes a 🚨 draft pull request. Journal in `/workspace/sre/journal.md` |
| **Cost Agent: test run** | Once | Pretends an instance costs 3 times its budget and does the rest for real, marked **💸 [test]** |
| **Cost Agent** | Every day | Checks each instance's cost against its **Monthly budget**. Over budget: plans the smallest cheaper config, checks nothing holding data gets replaced, then proposes it, all with 💸 messages. Journal in `/workspace/cost/journal.md` |

To test an agent, deploy it with its test run preset. It runs once after boot; its proposals and pull requests are real, so reject or close them. Then pick the real preset and deploy to put it on duty.

## Permissions

Give the agent a group that can view, plan and propose, never deploy. Then every change waits for a person to approve it in Massdriver, and every pull request waits for a person to merge it.

The SRE and Cost presets need no AWS access. Everything they read comes through Massdriver, so one agent covers every cloud account the organization manages. Decommission the agent and its service account goes with it.
