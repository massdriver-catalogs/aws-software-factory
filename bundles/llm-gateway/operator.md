# LLM Gateway

Connect to the gateway host:

```bash
aws ssm start-session --region {{dependencies.network.region}} \
  --target $(aws ec2 describe-instances --region {{dependencies.network.region}} \
    --filters Name=tag:Name,Values={{id}}-gateway Name=instance-state-name,Values=running \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)
```

## Every request returns 401

The key isn't under the gateway's prefix, or the sync hasn't run.

```bash
aws ssm get-parameters-by-path --region {{dependencies.network.region}} --path /{{id}}/keys --query 'Parameters[].Name'
```

On the host:

```bash
sudo systemctl status litellm-sync.timer
sudo journalctl -u litellm-sync -n 50
sudo python3 -c 'import json; print(list(json.load(open("/etc/litellm/keys.json")).values()))'
```

A failing sync is almost always IAM or egress. Check the error in the journal.

## Connection refused or timeout on port 4000

```bash
sudo systemctl status litellm
sudo docker logs --tail 100 litellm
```

If the container keeps restarting, the config is bad. Print it:

```bash
sudo cat /etc/litellm/config.yaml
```

Fix the model selection in Massdriver and redeploy; the host picks up the new config within a minute.

## A Bedrock model returns AccessDenied or "model not found"

The model isn't enabled in this account or region. Check:

```bash
aws bedrock list-foundation-models --region {{dependencies.network.region}} \
  --query 'modelSummaries[?contains(modelId, `gpt-oss`) || contains(modelId, `qwen`)].modelId'
```

If it's missing, open **Bedrock → Model access** in the console for this region and request it, or pick a different model.

## Self-hosted model is slow or unreachable

{{#dependencies.model_server}}
```bash
curl -s -H "Authorization: Bearer $(aws secretsmanager get-secret-value --region {{dependencies.network.region}} --secret-id {{dependencies.model_server.api_key_secret_arn}} --query SecretString --output text)" \
  {{dependencies.model_server.url}}/models
```
{{/dependencies.model_server}}

Run this from the gateway host. No answer means the model server is stopped (nightly stop) or still loading weights. Start it, or see the model server's runbook.

## Test a request end to end

```bash
KEY=$(sudo cat /etc/litellm/master_key)
curl -s localhost:4000/v1/chat/completions -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"model":"gpt-oss-20b","messages":[{"role":"user","content":"Say ok"}]}'
```
