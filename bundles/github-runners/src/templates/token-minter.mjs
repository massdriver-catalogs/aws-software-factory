import { createSign } from "node:crypto";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { SSMClient, PutParameterCommand } from "@aws-sdk/client-ssm";

const secrets = new SecretsManagerClient({});
const ssm = new SSMClient({});

const b64url = (value) => Buffer.from(value).toString("base64url");

function appJwt(appId, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  // iat is backdated because GitHub rejects tokens issued "in the future" by clock skew.
  const payload = b64url(JSON.stringify({ iat: now - 60, exp: now + 540, iss: String(appId) }));
  const signature = createSign("RSA-SHA256").update(`${header}.${payload}`).sign(privateKey, "base64url");
  return `${header}.${payload}.${signature}`;
}

async function github(method, path, token, scheme = "token") {
  const response = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Authorization: `${scheme} ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "massdriver-github-runners",
    },
  });
  if (!response.ok) {
    throw new Error(`${method} ${path}: ${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

export async function handler() {
  const { SecretString } = await secrets.send(new GetSecretValueCommand({ SecretId: process.env.APP_SECRET_ARN }));
  const app = JSON.parse(SecretString);

  const jwt = appJwt(app.app_id, app.private_key);
  const { token } = await github("POST", `/app/installations/${app.installation_id}/access_tokens`, jwt, "Bearer");

  const registration = await github("POST", `/orgs/${app.owner}/actions/runners/registration-token`, token);
  await ssm.send(
    new PutParameterCommand({
      Name: process.env.REGISTRATION_TOKEN_PARAMETER,
      Value: registration.token,
      Type: "SecureString",
      Overwrite: true,
    }),
  );

  // Runners whose VM was replaced or stopped stay registered as offline until removed.
  const prefix = `${process.env.RUNNER_NAME_PREFIX}-`;
  const removed = [];
  for (let page = 1; ; page++) {
    const { runners } = await github("GET", `/orgs/${app.owner}/actions/runners?per_page=100&page=${page}`, token);
    for (const runner of runners) {
      if (runner.name.startsWith(prefix) && runner.status === "offline" && !runner.busy) {
        await github("DELETE", `/orgs/${app.owner}/actions/runners/${runner.id}`, token);
        removed.push(runner.name);
      }
    }
    if (runners.length < 100) break;
  }

  return { registration_token_expires_at: registration.expires_at, removed };
}
