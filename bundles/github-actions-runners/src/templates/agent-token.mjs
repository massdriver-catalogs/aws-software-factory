import { createPublicKey, createSign, verify } from "node:crypto";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const secrets = new SecretsManagerClient({});
const ISSUER = "https://token.actions.githubusercontent.com";
const AUDIENCE = process.env.OIDC_AUDIENCE;
const WORKFLOW = process.env.AGENT_WORKFLOW;

const b64url = (value) => Buffer.from(value).toString("base64url");
const reply = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json" },
  body: JSON.stringify(body),
});

let jwksCache = { at: 0, keys: [] };
async function signingKey(kid) {
  if (Date.now() - jwksCache.at > 10 * 60 * 1000 || !jwksCache.keys.some((k) => k.kid === kid)) {
    const response = await fetch(`${ISSUER}/.well-known/jwks`);
    jwksCache = { at: Date.now(), keys: (await response.json()).keys };
  }
  const jwk = jwksCache.keys.find((k) => k.kid === kid);
  return jwk ? createPublicKey({ key: jwk, format: "jwk" }) : null;
}

async function verifyActionsToken(token) {
  const [header, payload, signature] = token.split(".");
  if (!signature) throw new Error("malformed token");
  const { kid, alg } = JSON.parse(Buffer.from(header, "base64url"));
  if (alg !== "RS256") throw new Error("unexpected algorithm");
  const key = await signingKey(kid);
  if (!key || !verify("RSA-SHA256", Buffer.from(`${header}.${payload}`), key, Buffer.from(signature, "base64url"))) {
    throw new Error("bad signature");
  }
  const claims = JSON.parse(Buffer.from(payload, "base64url"));
  const now = Math.floor(Date.now() / 1000);
  if (claims.iss !== ISSUER) throw new Error("wrong issuer");
  if (claims.aud !== AUDIENCE) throw new Error("wrong audience");
  if (claims.exp < now || (claims.nbf && claims.nbf > now + 60)) throw new Error("expired");
  return claims;
}

function appJwt(appId, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iat: now - 60, exp: now + 540, iss: String(appId) }));
  const signature = createSign("RSA-SHA256").update(`${header}.${payload}`).sign(privateKey, "base64url");
  return `${header}.${payload}.${signature}`;
}

export async function handler(event) {
  const auth = event.headers?.authorization || event.headers?.Authorization || "";
  const token = auth.replace(/^Bearer\s+/i, "");
  if (!token) return reply(401, { error: "send the job's GitHub OIDC token as a Bearer token" });

  let claims;
  try {
    claims = await verifyActionsToken(token);
  } catch (e) {
    return reply(401, { error: `invalid OIDC token: ${e.message}` });
  }

  const { SecretString } = await secrets.send(new GetSecretValueCommand({ SecretId: process.env.APP_SECRET_ARN }));
  const app = JSON.parse(SecretString);

  // Only the agent workflow, triggered by an issue event, gets a token. Issue
  // events always run the default branch's copy of a workflow, so a branch
  // that edits agent.yml can't mint a token for itself.
  const expectedRef = `${claims.repository}/.github/workflows/${WORKFLOW}@refs/heads/`;
  if (claims.repository_owner !== app.owner) return reply(403, { error: "repository outside this organization" });
  if (!claims.workflow_ref?.startsWith(expectedRef)) return reply(403, { error: `only ${WORKFLOW} may request a token` });
  if (claims.ref !== `refs/heads/${claims.workflow_ref.slice(expectedRef.length)}`) {
    return reply(403, { error: "workflow and ref disagree" });
  }
  if (!["issues", "issue_comment"].includes(claims.event_name)) return reply(403, { error: "only issue events" });

  const response = await fetch(`https://api.github.com/app/installations/${app.installation_id}/access_tokens`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${appJwt(app.app_id, app.private_key)}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "massdriver-agent-token",
    },
    body: JSON.stringify({
      repository_ids: [Number(claims.repository_id)],
      permissions: { contents: "write", pull_requests: "write", issues: "write" },
    }),
  });
  if (!response.ok) return reply(502, { error: `GitHub refused: ${response.status} ${await response.text()}` });
  const minted = await response.json();

  console.log(JSON.stringify({ repository: claims.repository, run_id: claims.run_id, actor: claims.actor }));
  return reply(200, { token: minted.token, expires_at: minted.expires_at });
}
