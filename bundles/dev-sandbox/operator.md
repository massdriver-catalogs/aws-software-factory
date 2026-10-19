# Developer Sandbox

Find the instance first:

```bash
aws ec2 describe-instances --region {{dependencies.network.region}} \
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
- **`SessionManagerPlugin is not found`:** `brew install --cask session-manager-plugin`, or the installer for your OS.

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

## Setup didn't finish

```bash
sudo tail -n 50 /var/log/dev-sandbox-setup.log
ls /var/lib/dev-sandbox-ready
```

The log shows the step that failed, usually a download. Redeploying rebuilds the VM and runs setup again; `/workspace` is kept.
