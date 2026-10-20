---
templating: mustache
---
# Budget Guard

## A spend alert fired

Find what's costing money, by service, for this month:

```bash
aws ce get-cost-and-usage --time-period Start=$(date +%Y-%m-01),End=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d tomorrow +%Y-%m-%d) \
  --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[?Metrics.UnblendedCost.Amount>`1`].[Keys[0],Metrics.UnblendedCost.Amount]' --output table
```

The usual suspects:

- **EC2 - Other / Amazon EC2:** a GPU model server left running. Check that its idle and nightly stops are on, or stop it.
- **Amazon Bedrock:** token spend. The LLM gateway's logs show which consumer.
- **EC2 - Other with NAT in the usage type:** a NAT gateway and its data charges. A NAT instance is cheaper.

## Alerts aren't arriving by email

Each address gets a confirmation email from AWS when it's added, and nothing is delivered until it's confirmed. Check spam for "AWS Notification - Subscription Confirmation".

## The limit is wrong

Change **Monthly limit (USD)** and redeploy. The budget keeps its history.
