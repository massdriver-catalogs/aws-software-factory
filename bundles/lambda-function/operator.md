---
templating: mustache
---
# Lambda Function

## Read the logs

```bash
aws logs tail /aws/lambda/{{id}} --region {{dependencies.api.region}} --since 15m --follow
```

## Errors alarm, or 500 from the API

Find the failing invocations:

```bash
aws logs filter-log-events --region {{dependencies.api.region}} --log-group-name /aws/lambda/{{id}} \
  --start-time $(( ($(date +%s) - 3600) * 1000 )) --filter-pattern '?ERROR ?"Task timed out"' \
  --query 'events[].message' --output text | tail -20
```

- **`Task timed out after N seconds`:** raise **Timeout**, or make the work smaller. Requests through the API can't run past 30 seconds.
- **`Runtime exited` / `out of memory`:** raise **Memory (MB)**.
- **`AccessDeniedException` on DynamoDB:** set **Table access** to read-write if the function writes.
- **Stack trace from the app:** it's in the code. Fix it and push a new image.

## The image won't deploy

- **`exec format error` or `InvalidImage`:** the image isn't arm64. Rebuild with `--platform linux/arm64`.
- **`Source image ... does not exist`:** the tag or digest isn't in ECR, or the repository is in another account or region.

## Run it without the API

```bash
aws lambda invoke --region {{dependencies.api.region}} --function-name {{id}} \
  --payload '{"version":"2.0","routeKey":"GET /","rawPath":"/","requestContext":{"http":{"method":"GET","path":"/"}}}' \
  --cli-binary-format raw-in-base64-out /dev/stdout
```

## Calls to the AI Platform fail

{{#dependencies.llm}}
- **Timeout:** the function isn't in the VPC, or the gateway is down. Check the function's VPC config, then the gateway's runbook.
- **401:** the gateway hasn't picked up this function's key yet (it checks every minute), or the parameter `{{dependencies.llm.key_parameter_prefix}}/{{id}}` was deleted. Redeploying writes a new key.
- **Model not found:** `OPENAI_MODEL` names a model the gateway no longer serves. Redeploy to pick up its current default.
{{/dependencies.llm}}
{{^dependencies.llm}}
No LLM Endpoint is connected. Connect the AI Platform's LLM Endpoint and the VPC, then redeploy.
{{/dependencies.llm}}

## Routes answer without sign-in

{{#params.require_sign_in}}
**Require sign-in** is on, so the API had no user pool when this function last deployed. Check:

```bash
aws lambda get-function-configuration --region {{dependencies.api.region}} --function-name {{id}} --query Description
```

`PUBLIC: …` confirms it. Connect a user pool to the HTTP API, redeploy the API, then redeploy this function.
{{/params.require_sign_in}}
{{^params.require_sign_in}}
**Require sign-in** is off. Turn it on, and make sure the HTTP API has a user pool connected.
{{/params.require_sign_in}}
