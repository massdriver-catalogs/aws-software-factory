# Developer Sandbox

A cloud VM for one developer, where coding agents can work with broad permissions because the worst they can break is a disposable machine. Add one environment per developer to get one sandbox each.

## What's on it

- `dev` user with passwordless sudo, docker, git, tmux and herdr
- mise with the chosen languages
- The chosen coding agents, already configured for the AI Platform when it's connected
- The `mass` CLI
- Your dotfiles, if you gave a repository

Work goes in `/workspace`. It's a separate disk that survives the VM being rebuilt; docker images and build cache live there too. Everything else is rebuilt from scratch on each new release of this bundle.

## Connecting

There are no inbound ports and no SSH keys. Connect through Session Manager:

- **AWS Console:** EC2 → the instance → **Connect** → **Session Manager**, then run `sudo -iu dev`.
- **AWS CLI:** `aws ssm start-session --target <instance-id> --document-name <instance-name>-shell` drops you straight into the `dev` user.

Start `herdr` to run several agents side by side, or `opencode` for one.

## AI Platform

When the environment has an LLM Endpoint, the sandbox writes its own key where the gateway picks it up and points each agent at the gateway. Nothing is copied by hand. Without one, the agents are installed but have no model configured.

## Stopping

The VM stops itself after the chosen idle time (CPU near zero) and at the nightly stop time. Start it again from the EC2 console or `aws ec2 start-instances`. A stopped sandbox costs only its disks.

## Not included yet

Browser access (opencode web) and GitHub credentials.
