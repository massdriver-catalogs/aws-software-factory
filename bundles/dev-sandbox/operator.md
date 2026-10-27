---
templating: mustache
---
# Developer Sandbox

## Connect

No AWS login needed. The sandbox's own key can only wake it and open a session on it.

**One-time setup on your machine.** On a Mac:

```bash
brew install awscli
curl -fsSLo /tmp/smp.zip "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$([ "$(uname -m)" = arm64 ] && echo mac_arm64 || echo mac)/sessionmanager-bundle.zip"
unzip -qo /tmp/smp.zip -d /tmp
sudo /tmp/sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

On Linux or Windows, install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

{{#resources.access}}
**Set up this sandbox.** Download and run its connect script, either from the **Connect to {{id}}** resource's **Connect script** button or from a terminal:

```bash
mass resource download {{id}}.access --format sh > {{id}}.sh
sh {{id}}.sh
```

It adds an AWS profile and an SSH host, both named `{{id}}`, plus an SSH key just for this sandbox. Run it again only if the sandbox is decommissioned and recreated.
{{/resources.access}}
{{^resources.access}}
The connect script appears once the sandbox has deployed.
{{/resources.access}}

**Connect:**

```bash
ssh {{id}}
```

If it's stopped, this starts it first; allow about a minute. In VS Code or Cursor: **Remote-SSH: Connect to Host…** → `{{id}}`. Work lives in `/workspace`; run `opencode`, or `herdr` for several agents side by side.

To look up the instance:

```bash
aws ec2 describe-instances --profile {{id}} --region {{dependencies.network.region}} \
  --filters Name=tag:Name,Values={{id}} \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
```

## Can't connect

`ssh {{id}}` is set up by the connect script on this sandbox's **Connect to {{id}}** resource. Run `ssh -v {{id}}` and match the last lines:

- **`Starting {{id}}...` then nothing:** the VM is booting. The first connection after a stop takes about a minute.
- **`Permission denied (publickey…)` right after a rebuild:** setup hasn't created the `dev` user yet. It takes a few minutes after a rebuild; try again. If it persists, see **Setup didn't finish**.
- **`TargetNotConnected` or the wait for Online times out:** the SSM agent can't reach AWS.

  ```bash
  aws ssm describe-instance-information --profile {{id}} --region {{dependencies.network.region}} \
    --filters Key=InstanceIds,Values=<id> --query 'InstanceInformationList[].PingStatus'
  ```

  Nothing back means no route out. In private network mode, check the shared VPC's egress (its runbook: "Private subnets lost internet access").
- **`AccessDenied` or `InvalidClientTokenId`:** the sandbox was decommissioned and recreated since you ran the connect script, so it has a new key. Download the connect script again and re-run it.
- **`SessionManagerPlugin is not found`:** install the plugin as in **Connect** above. Homebrew's cask is disabled, so it comes from AWS's download.

Without the script, the AWS console works too: EC2 → the instance → **Connect** → **Session Manager**, then `sudo -iu dev`.

## An agent can't reach the model

From the sandbox, as `dev`:

```bash
. ~/.config/sandbox/llm.env
curl -s -H "Authorization: Bearer $AIPLATFORM_API_KEY" "$AIPLATFORM_BASE_URL/models"
```

- **`llm.env` is empty:** the environment had no LLM Endpoint when the sandbox was built. Set one as the environment default and redeploy.
- **Connection refused:** the gateway machine is up but its service isn't. Check the AI Platform gateway's runbook.
- **Timeout:** the gateway is down or its security group doesn't admit the VPC. Check the AI Platform's gateway.
- **401:** the gateway hasn't picked up this sandbox's key yet (it checks periodically), or the key parameter was deleted. Redeploying the sandbox writes a new one.

## Disk full

```bash
df -h / /workspace
docker system df
```

- **`/workspace` full:** `docker system prune -a` usually frees the most. For more space, raise **Workspace disk** and redeploy, then grow the filesystem: `sudo xfs_growfs /workspace`.
- **`/` full:** it's small on purpose; something is writing outside `/workspace`. `sudo du -xh / --max-depth=2 | sort -h | tail` finds it.

## Stopped unexpectedly

```bash
aws cloudwatch describe-alarm-history --region {{dependencies.network.region}} \
  --alarm-name {{id}}-idle-stop --history-item-type Action --max-records 5
```

An entry means the idle stop fired: CPU stayed under 3% for {{params.idle_stop}}. A human reading code and an agent waiting on the model both look idle. Pick a longer **Stop when idle for**, or **Never**, if this keeps happening.

No entry and it stopped around {{params.nightly_stop}} ({{params.timezone}}): that was the nightly stop.

## Massdriver tools don't work

As `dev`:

```bash
sandbox-massdriver-login
```

- **"No Massdriver key … tools stay off":** no groups are picked in **Massdriver access for agents**, or the environment has no Massdriver Service Account credential. Pick groups and redeploy. A new shell picks the key up within 5 minutes; `sandbox-massdriver-login` does it right away.
- **Tools are on but calls are denied:** the groups picked don't allow that action. Add a policy to the group, or pick another group.
- **"must be JSON with api_key and organization_id":** the secret holds a bare key. Replace it with the JSON form using `aws secretsmanager put-secret-value`.
- **The MCP server fails to start in opencode:** run it by hand to see why.

  ```bash
  . ~/.config/sandbox/massdriver.env
  echo '{}' | docker run -i --rm -e MASSDRIVER_API_KEY -e MASSDRIVER_ORGANIZATION_ID -e MASSDRIVER_URL docker.io/massdrivercloud/mcp-server:0.2.0
  ```

  `Unable to find image` means setup couldn't pull it, usually egress; `docker pull` it. `401` or `unauthorized` means the key is wrong or its service account was deleted; replace the secret's value.
- **`mass` says it isn't authenticated:** run `mass whoami` in a new shell. Shells opened before the login don't have the key.

## GitHub access fails

From the sandbox, as `dev`:

```bash
sandbox-github-token token >/dev/null && echo "token ok"
git config --global --get-regexp '^credential'
```

- **`ResourceNotFoundException` / `AccessDenied` from Secrets Manager:** the environment had no GitHub App connection when the sandbox was built. Set the GitHub App as the environment default and redeploy.
- **`401` from api.github.com:** the App's key in the GitHub App credential was rotated or revoked. Update the credential in Massdriver and redeploy the sandbox.
- **`404` from api.github.com:** the App was uninstalled from the organization, or the installation ID changed. Reinstall it and update the credential.
- **Clone asks for a username:** the URL isn't `https://github.com/{{#dependencies.github}}{{dependencies.github.owner}}{{/dependencies.github}}/…`. SSH URLs and other organizations aren't covered by the App.
- **Push rejected with "refusing to allow a GitHub App to create or update workflow":** the App lacks the Workflows permission. Grant it in the App's settings and accept the new permissions on the installation.
- **A stale token after the App's permissions changed:** `rm ~/.cache/sandbox/github-token.json` and retry.

## Browser access doesn't load

{{#params.browser_access}}
{{#resources.access}}
Browser: {{resources.access.browser_url}} · Preview: {{resources.access.preview_url}}
{{/resources.access}}

- **504 or "origin not reachable":** the sandbox is stopped. `ssh {{id}}` starts it; the page answers about a minute later.
- **502 on the browser URL:** opencode's web server isn't running.

  ```bash
  ssh {{id}} 'systemctl status opencode-web --no-pager; journalctl -u opencode-web -n 50 --no-pager'
  ```

  `sudo systemctl restart opencode-web` restarts it. If its password file is missing, the sandbox role can't read its browser-password secret.
- **502 on the preview URL:** nothing is listening on the preview port, or the dev server is bound to localhost only. Start it with `--host` / `--bind 0.0.0.0`.
- **401 again and again:** the password is wrong or from before browser access was turned off and on again. Download and run the connect script again for the current one.
- **Right after a redeploy that rebuilt the VM:** CloudFront is moving to the new VM, which takes up to 15 minutes.
{{/params.browser_access}}
{{^params.browser_access}}
Browser access is off. Turn on **Browser access** (with **Private** network mode) and redeploy.
{{/params.browser_access}}

## The goal isn't running

```bash
systemctl list-timers sandbox-goal.timer
journalctl -u sandbox-goal -n 50
ls -t /workspace/.goal/runs | head
```

- **No runs at all:** the goal is empty, or **Once** already ran this goal. Run `sandbox-goal --now`.
- **A run never ends:** runs stop after 2 hours. The next one starts when the last finishes; `/workspace/.goal/lock` keeps them from overlapping.
- **The agent says it isn't allowed:** **Ask before editing** is set. A headless agent can't ask; set autonomy to run freely.
- **The VM stopped:** only a repeating goal turns the idle and nightly stops off.

## Setup didn't finish

```bash
sudo tail -n 50 /var/log/dev-sandbox-setup.log
ls /var/lib/dev-sandbox-ready
```

The log shows the step that failed, usually a download. Redeploying rebuilds the VM and runs setup again; `/workspace` is kept.
