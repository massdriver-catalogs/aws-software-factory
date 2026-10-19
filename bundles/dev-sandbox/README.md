# Developer Sandbox

A cloud VM for one developer, where coding agents can work with broad permissions because the worst they can break is a disposable machine. Add one environment per developer to get one sandbox each.

## What's on it

- `dev` user with passwordless sudo, docker, git, tmux and herdr
- mise with the chosen languages
- The chosen coding agents, already configured for the AI Platform when it's connected
- The `mass` CLI
- Your dotfiles, if you gave a repository

Work goes in `/workspace`. It's a separate disk that survives the VM being rebuilt; docker images and build cache live there too. Everything else is rebuilt from scratch on each new release of this bundle.

## Connecting for the first time

You don't need an AWS login. Each sandbox comes with its own key, which can only wake this sandbox and open a session on it.

1. **Install the tools once.** On a Mac:

   ```bash
   brew install awscli
   brew install --cask session-manager-plugin
   ```

   On Linux or Windows, install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

2. **Download the connect script.** Open this sandbox's **Connect to …** resource in Massdriver and click **Connect script** (it downloads with a `.yaml` name; it's a shell script either way), or from a terminal:

   ```bash
   mass resource download <project>-<environment>-sandbox.access --format yaml > sandbox.sh
   ```

3. **Run it.**

   ```bash
   sh sandbox.sh    # or: sh ~/Downloads/<downloaded file>
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

When the environment has an LLM Endpoint, the sandbox writes its own key where the gateway picks it up and points each agent at the gateway. Nothing is copied by hand. Without one, the agents are installed but have no model configured.

## Stopping

The VM stops itself after the chosen idle time (CPU near zero) and at the nightly stop time. `ssh` starts it again. A stopped sandbox costs only its disks.

## Not included yet

Browser access (opencode web) and GitHub credentials.
