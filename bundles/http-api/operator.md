---
templating: mustache
---
# HTTP API

{{#resources.api}}
## Call it

```bash
curl -i {{resources.api.endpoint}}/
```

## 404 Not Found

No route matches. List what's attached:

```bash
aws apigatewayv2 get-routes --region {{params.region}} --api-id {{resources.api.id}} --query 'Items[].RouteKey'
```

Routes come from connected functions; add the route to the function that should answer it.

## 429 Too Many Requests

The throttle is doing its job. If the traffic is real, raise **Steady requests per second** and **Burst requests**.

## 500 or 503 from a route

The function failed or timed out. The access log has the reason:

```bash
aws logs tail /aws/apigateway/{{id}} --region {{params.region}} --since 15m --format short | grep -v '"status":"2'
```

`integrationError` names the problem. A timeout means the function ran past 30 seconds, which the API can't wait for.

## CORS errors in the browser

The page's origin must match one of **Browser origins allowed to call it** exactly, including scheme and port.
{{/resources.api}}
