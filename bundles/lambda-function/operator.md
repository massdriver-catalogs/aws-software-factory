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
