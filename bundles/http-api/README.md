# HTTP API

An API Gateway HTTP API with a single stage, `$default`, that deploys every change immediately. It has no routes of its own: each connected function adds the routes it answers, so one API can sit in front of several functions.

## Throttling

**Steady requests per second** and **Burst requests** apply to every route. Requests above them get `429 Too Many Requests` and never reach a function, which also caps what a misbehaving client can cost.

## CORS

Only needed when a web page served from a different origin calls the API from the browser. API Gateway answers the browser's preflight request itself.

## Logs

Each request writes one JSON line to `/aws/apigateway/<name>`: route, status, latency, and the integration error if the function failed.

## Sign-in

Connect a **User Pool** and the API verifies its tokens. Each function decides whether its routes need them, with **Require sign-in**. A request to a protected route without a valid `Authorization: Bearer <token>` header gets `401` and never reaches the function. A route that doesn't require sign-in stays public even with a pool connected.
