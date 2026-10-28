---
templating: mustache
---
# Agent

## Connect

No AWS login needed. The agent's own key can only wake its VM and open a session on it.

**One-time setup on your machine.** On a Mac:

```bash
brew install awscli
curl -fsSLo /tmp/smp.zip "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$([ "$(uname -m)" = arm64 ] && echo mac_arm64 || echo mac)/sessionmanager-bundle.zip"
unzip -qo /tmp/smp.zip -d /tmp
sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

On Linux or Windows, install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

{{#resources.access}}
**Set up this agent.** Download and run its connect script, either from the **Connect to {{id}}** resource's **Connect script** button or from a terminal:

```bash
mass resource download {{id}}.access --format sh > {{id}}.sh
sh {{id}}.sh
```

It adds an AWS profile and an SSH host, both named `{{id}}`, plus an SSH key just for this agent. Run it again only if the agent is decommissioned and recreated.
{{/resources.access}}
{{^resources.access}}
The connect script appears once the agent has deployed.
{{/resources.access}}

**Connect:**

```bash
ssh {{id}}
```

## Read what it did

```bash
ls -t /workspace/.goal/runs | head
less "/workspace/.goal/runs/$(ls -t /workspace/.goal/runs | head -1)"
```

The SRE Agent preset keeps its journal in `/workspace/sre/journal.md`; the Cost Agent preset in `/workspace/cost/journal.md`. A prompt of your own keeps whatever it was told to keep.

## Run it now

```bash
sandbox-goal --now
```

## Run a test

Pick the **SRE Agent: test run** or **Cost Agent: test run** preset and deploy. It fakes its trigger and does everything else for real, once. Proposals and pull requests it opens are real: reject or close them afterwards. Pick the real preset again and deploy to put it back on duty.

## Change what it does

Edit **Prompt** or **Schedule** on this instance and deploy. The prompt is read on each run, so the VM isn't rebuilt; the next run uses it. To get a preset's prompt back, pick the preset again and deploy.

## The prompt isn't running

```bash
systemctl list-timers sandbox-goal.timer
journalctl -u sandbox-goal -n 50
```

- **No runs at all:** the schedule is **Once** and it already ran this prompt. Run `sandbox-goal --now`.
- **A run never ends:** runs stop after 2 hours. The next one starts when the last finishes; `/workspace/.goal/lock` keeps them from overlapping.
- **Runs end at once with a model error:** the gateway stopped this agent's key at its monthly cap, or the environment has no LLM endpoint. Check the AI Platform gateway.

## Massdriver calls are denied

```bash
sandbox-massdriver-login
mass whoami
```

- **"No Massdriver key … tools stay off":** no groups are picked in **Massdriver groups**, or the environment has no Massdriver Service Account credential. Pick a group and redeploy.
- **A plan or proposal is denied:** the group doesn't allow `instance:plan` or `instance:propose`. Add a policy to the group.
- **A deploy is denied:** working as intended. Agents propose; a person approves.

## Setup didn't finish

```bash
sudo tail -n 50 /var/log/dev-sandbox-setup.log
```

The log shows the step that failed, usually a download. Redeploying rebuilds the VM and runs setup again; `/workspace` is kept.
