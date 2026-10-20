---
templating: mustache
---
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

## Who is spending what

Tokens and estimated cost by consumer and model, from the request logs. Set the start to midnight UTC for today, or the 1st for the month:

```bash
aws logs start-query --region {{dependencies.network.region}} --log-group-name /{{id}}/gateway \
  --start-time $(date -u -d "$(date -u +%Y-%m-%d)" +%s) --end-time $(date +%s) \
  --query-string 'filter event = "usage" | stats count(*) as requests, sum(input_tokens) as input, sum(output_tokens) as output, sum(cost_usd) as usd by consumer, model | sort usd desc'
aws logs get-query-results --region {{dependencies.network.region}} --query-id <query-id>
```

On macOS, replace the `date -u -d …` with `$(date -u -j -f %Y-%m-%d "$(date -u +%Y-%m-%d)" +%s)`.

This month's running totals:

```bash
aws dynamodb scan --region {{dependencies.network.region}} --table-name {{id}}-usage \
  --query 'Items[].[consumer.S, month.S, cost_usd.N, requests.N]' --output table
```

## A consumer gets 429 "Monthly AI budget reached"

It spent its budget for the month. If that's expected work, raise **Monthly budget per consumer** or add a **Budget override** for that consumer and redeploy; it takes effect within a minute. If it isn't, find what it's been doing with the query above. A runaway agent loop shows up as a high request count.

To reset one consumer's spend for the month:

```bash
aws dynamodb delete-item --region {{dependencies.network.region}} --table-name {{id}}-usage \
  --key '{"consumer":{"S":"<consumer>"},"month":{"S":"<YYYY-MM>"}}'
```

## Test a request end to end

```bash
KEY=$(sudo cat /etc/litellm/master_key)
curl -s localhost:4000/v1/chat/completions -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"model":"gpt-oss-20b","messages":[{"role":"user","content":"Say ok"}]}'
```
