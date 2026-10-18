# Developer Sandbox

Find the instance first:

```bash
aws ec2 describe-instances --region {{dependencies.network.region}} \
  --filters Name=tag:Name,Values={{id}} \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text
```

## Can't connect

1. **Stopped?** Start it: `aws ec2 start-instances --region {{dependencies.network.region}} --instance-ids <id>`. Give it a minute.
2. **Not in Session Manager?**

   ```bash
   aws ssm describe-instance-information --region {{dependencies.network.region}} \
     --filters Key=InstanceIds,Values=<id> --query 'InstanceInformationList[].PingStatus'
   ```

   Nothing back means the SSM agent can't reach AWS. In private network mode, check the shared VPC's egress is up (its runbook: "Private subnets lost internet access").
3. **Your own permissions:** you need `ssm:StartSession` on the instance and, for the CLI shortcut, on the `{{id}}-shell` document.

## An agent can't reach the model

From the sandbox, as `dev`:

```bash
. ~/.config/sandbox/llm.env
curl -s -H "Authorization: Bearer $AIPLATFORM_API_KEY" "$AIPLATFORM_BASE_URL/models"
```

- **`llm.env` is empty:** the environment had no LLM Endpoint when the sandbox was built. Set one as the environment default and redeploy.
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
