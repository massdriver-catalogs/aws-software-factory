# Developer Sandbox

A cloud VM for one developer, where coding agents can work with broad permissions because the worst they can break is a disposable machine. Add one environment per developer to get one sandbox each.

## What's on it

- `dev` user with passwordless sudo, docker, git, the GitHub CLI (`gh`), tmux and herdr
- mise with the chosen languages
- The chosen coding agents, already configured for the AI Platform when it's connected
- Massdriver tooling: the `mass` CLI, the Massdriver MCP server for agents, and the Massdriver plugin for Claude Code when it's selected
- Your dotfiles, if you gave a repository

Work goes in `/workspace`. It's a separate disk that survives the VM being rebuilt; docker images and build cache live there too. Everything else is rebuilt from scratch on each new release of this bundle.

## Connecting for the first time

You don't need an AWS login. Each sandbox comes with its own key, which can only wake this sandbox and open a session on it.

1. **Install the tools once.** On a Mac:

   ```bash
   brew install awscli
   curl -fsSLo /tmp/smp.zip "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$([ "$(uname -m)" = arm64 ] && echo mac_arm64 || echo mac)/sessionmanager-bundle.zip"
   unzip -qo /tmp/smp.zip -d /tmp
   sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
   ```

   On Linux or Windows, install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

2. **Download the connect script.** Open this sandbox's **Connect to …** resource in Massdriver and click **Connect script**, or from a terminal:

   ```bash
   mass resource download <project>-<environment>-sandbox.access --format sh > sandbox.sh
   ```

3. **Run it.**

   ```bash
   sh sandbox.sh
   ```

   It adds an AWS profile and an SSH host, both named after the sandbox, and makes an SSH key just for it. Nothing else on your machine changes.

4. **Connect.**

   ```bash
   ssh <sandbox-name>
   ```

   If the sandbox is stopped, this starts it first; the first connection after a stop takes about a minute. In VS Code or Cursor, use **Remote-SSH: Connect to Host…** and pick the same name.

Run the script again only if the sandbox is decommissioned and recreated. Rebuilds and stops don't change anything on your side.

Once in, start `herdr` to run several agents side by side, or `opencode` for one.

## AI Platform

```mermaid
flowchart LR
  A[opencode / Claude Code<br/>in this sandbox] -->|gateway URL + this sandbox's key| G[LLM Gateway]
  G --> M[Bedrock or self-hosted models]
```

When the environment has an LLM Endpoint, the sandbox writes its own key where the gateway picks it up, and points each agent at the gateway with every model it serves. Nothing is copied by hand. Without one, the agents are installed but have no model configured.

Agents start on the gateway's default model. To use another, run `/models` inside opencode, or start it with `opencode -m aiplatform/<model>`. Models added to the gateway later show up after the sandbox is redeployed.

## Massdriver tools

Agents can drive Massdriver through its MCP server, and the `mass` CLI is on the path. Both stay off until the sandbox has a Massdriver key.

To turn them on, connect a Massdriver Service Account credential to the environment and pick groups in **Massdriver access for agents**. The sandbox gets its own service account in those groups, and its agents get exactly those permissions. The key goes to Secrets Manager at `<sandbox-name>/massdriver-api-key` and is loaded at boot.

A sandbox that's already running loads it the next time you run `sandbox-massdriver-login` and open a new shell. Empty the list and redeploy to remove the service account.

## AWS access

**AWS access for agents** attaches a read-only AWS policy to the sandbox's role, so agents and the `aws` CLI can look around the account:

- **Alarms, metrics, logs and resource lists:** `CloudWatchReadOnlyAccess` and `ViewOnlyAccess`.
- **Read everything:** `ReadOnlyAccess`, which includes S3 objects and table data.

Neither can change anything. Anyone with a shell on the sandbox has the same access.

## Goal

Give the sandbox a **Goal** and it works without anyone attached. A timer checks every minute and runs the agent headless in `/workspace`: Claude Code when it's installed, otherwise opencode. Each run's output goes to `/workspace/.goal/runs`, and the last 100 are kept.

- **Once** runs it after boot, and again whenever the goal changes.
- **Every 5 minutes** to **Every day** repeat it, and turn off the idle and nightly stops so the VM stays up.

The goal is read on each run, so changing it never rebuilds the VM. Run it on demand with `sandbox-goal --now`. With **Ask before editing** set, a headless agent can't ask, so actions that need permission are refused.

## Applications

This bundle is a runtime. An application on it ships a ready-made agent through three app envs:

| Env | Value |
|---|---|
| `AGENT_GOAL` | The goal |
| `AGENT_GOAL_EVERY` | `once`, `5m`, `15m`, `1h`, `6h` or `1d` |
| `AGENT_CLI` | `claude-code` or `opencode`, installed even if it isn't picked |
| `AGENT_TEST_GOAL` | A run that fakes the trigger, to show the agent working; `sandbox-goal --test` runs it |

Its other app envs and secrets are exported to each goal run. A goal typed into the form replaces the application's, schedule included.

## GitHub

```mermaid
flowchart LR
  G[git / gh in the sandbox] -->|needs a token| H[sandbox-github-token]
  H -->|App key, read into memory| S[Secrets Manager]
  H -->|signed request| A[GitHub: installation token, 1 hour]
  A --> G
```

When the environment has a **GitHub App** connection, `git clone`, `git push` and `gh` work against the App's organization with no personal token. The sandbox keeps its own copy of the App's key in Secrets Manager, readable only by its role. When git or `gh` needs access, it mints an installation token that lasts an hour, caches it, and mints a new one shortly before it expires. The key itself is never written to disk.

Use HTTPS URLs (`https://github.com/<org>/<repo>`). Repositories outside the App's organization get no token and ask for credentials as usual.

Commits are authored as **Your name for commits** and **Your email for commits**. Use an address on your GitHub account and commits link to your profile; pushes always show the App as the pusher.

## Browser access

Turn on **Browser access** and the sandbox gets two HTTPS URLs, both behind one username and password:

- **opencode in a browser tab**, the same agents and workspace as over SSH;
- **an app preview**, whatever your dev server serves on the **Preview port**.

```mermaid
flowchart LR
  B[Your browser] -->|HTTPS + password| C[CloudFront]
  C -->|private connection| O[opencode web :4096]
  C -->|private connection| P[your dev server :preview port]
  subgraph S[Sandbox, private subnet]
    O
    P
  end
```

CloudFront reaches the sandbox over a private connection into the VPC, so nothing on the sandbox is open to the internet, and only that CloudFront connection is allowed in on those two ports. That connection only works into a private subnet, so browser access needs **Private** network mode.

The URLs and password are on this sandbox's **Connect to …** resource, and the connect script prints them. Dev servers must listen on all interfaces to be previewed: `npm run dev -- --host`, `python -m http.server 5173 --bind 0.0.0.0`.

A stopped sandbox can't answer, so the URLs fail until it's started again; `ssh` to it wakes it. Rebuilding the sandbox (a new release, a changed setting) moves the URLs onto the new VM, which takes CloudFront about 15 minutes.

## Stopping

The VM stops itself after the chosen idle time (CPU near zero) and at the nightly stop time. `ssh` starts it again. A stopped sandbox costs only its disks.
