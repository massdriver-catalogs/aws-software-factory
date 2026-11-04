# Todo App

The example app the factory builds: a Python function behind the HTTP API that keeps its todos in one table. Its code lives in the `todoapp` repository the GitHub Repository bundle creates, and every merge ships a new image to dev.

Todo App is an application on the `lambda-function` runtime. The runtime runs it behind the HTTP API and owns its image, routes, memory and sign-in.

## Tables

| Dependency | Holds | Environment variables |
|---|---|---|
| `todos` | The todos | `TABLE_NAME`, `TABLE_PARTITION_KEY` |

The function gets read-write access to it.

## Project

Todo App is its own project with a `dev` environment: a User Pool for sign-in, an HTTP API that checks it, the Todos Table, this application linked to the API and the table, a Static Site linked to the API, and Alarm to Issue. Its GitHub and ECR repositories are in the Codebases environment `todoapp`.

## Calling the API

Every route requires sign-in, so each call carries a token from the User Pool. You need these values:

| Value | Where it comes from |
|---|---|
| `API` | The HTTP API's `endpoint` |
| `SIGN_IN` | The User Pool's `sign_in_url` |
| `CLIENT_ID` | The User Pool's `client_id` |
| `CALLBACK` | One of the User Pool's callback URLs, usually the Static Site's URL |

The client only signs in through the browser, using an authorization code with PKCE. To get a token, make a verifier and open the sign-in page:

```bash
VERIFIER=$(openssl rand -base64 48 | tr -d '=+/\n' | cut -c1-64)
CHALLENGE=$(printf %s "$VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr '+/' '-_' | tr -d '=\n')
open "$SIGN_IN/oauth2/authorize?response_type=code&client_id=$CLIENT_ID&redirect_uri=$CALLBACK&scope=openid+email&code_challenge_method=S256&code_challenge=$CHALLENGE"
```

After you sign in, the browser lands on the callback URL with `?code=...` on the end. Copy that code into `CODE`, then trade it for a token:

```bash
TOKEN=$(curl -s "$SIGN_IN/oauth2/token" \
  -d grant_type=authorization_code -d client_id="$CLIENT_ID" \
  -d redirect_uri="$CALLBACK" -d code="$CODE" -d code_verifier="$VERIFIER" \
  | jq -r .access_token)
```

The code works once and expires after five minutes. The token lasts an hour.

| Route | Returns |
|---|---|
| `GET /` | A greeting and the table's name |
| `GET /health` | `{"ok": true}` |
| `GET /version` | The running version |

```bash
curl -s "$API/" -H "Authorization: Bearer $TOKEN"
curl -s "$API/health" -H "Authorization: Bearer $TOKEN"
curl -s "$API/version" -H "Authorization: Bearer $TOKEN"
```

Without a token, every route returns `401`. A path that isn't listed returns `404`.
