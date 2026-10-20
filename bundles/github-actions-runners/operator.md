---
templating: mustache
---
# GitHub Runners

{{#resources.runners}}
## See the runners

```bash
gh api orgs/{{resources.runners.organization}}/actions/runners \
  --jq '.runners[] | select(.name | startswith("{{id}}-")) | [.name, .status, .busy] | @tsv'
```

Idle runners show `online` and not busy. While a job runs, its runner is busy, and afterwards it re-registers under the same name.

## Jobs wait in "Queued" forever

- **No runner online:** see **Runners are offline**.
- **Labels don't match:** the job's `runs-on` must be a subset of {{#resources.runners.labels}}`{{.}}` {{/resources.runners.labels}}.
- **Public repository:** the Default runner group only serves private repositories. Allow public ones under **Organization settings → Actions → Runner groups → Default**, or keep the repository private.
- **All runners busy:** raise **Runners**.
{{/resources.runners}}

## Runners are offline

Check that registration tokens are being minted:

```bash
aws lambda invoke --region {{dependencies.network.region}} --function-name {{id}}-token-minter /dev/stdout
```

- **An error naming `access_tokens` or `registration-token`:** the GitHub App credential is wrong, or the app lost the organization permission **Self-hosted runners: Read and write**, or it was uninstalled.
- **It succeeds:** the problem is on the VMs. Connect with Session Manager and read the loop's log:

  ```bash
  aws ssm start-session --region {{dependencies.network.region}} --target <instance-id>
  sudo journalctl -u factory-runner -n 50
  sudo tail -n 50 /var/log/factory-runner-setup.log
  ```

  `Could not resolve host` or timeouts mean the VMs have no internet: check the shared VPC's egress. `Http response code: NotFound` from `config.sh` usually means the token expired; the next mint fixes it within 30 minutes, or invoke the minter by hand as above.

## "The runner version is deprecated" or jobs never start after a GitHub release

Runners don't update themselves, so jobs never race an update. When GitHub stops accepting the pinned version, bump `runner_version` in this bundle and redeploy; the VMs are rebuilt with the new runner.

## A job can't reach the AI Platform

```bash
curl -s -H "Authorization: Bearer $OPENAI_API_KEY" "$OPENAI_BASE_URL/models"
```

Run that as a step in the failing workflow.

- **`OPENAI_BASE_URL` is empty:** no LLM Endpoint was connected when the runners were built. Connect it and redeploy.
- **401:** the gateway hasn't picked up the runners' key yet (it checks every minute), or the parameter was deleted. Redeploying writes a new key.
- **Timeout:** the gateway is down. Check its runbook.

## Disk full

Docker images and caches accumulate between jobs. On the runner:

```bash
sudo docker system prune -af
```

Or raise **Disk (GB)** and redeploy, which rebuilds the VMs.
