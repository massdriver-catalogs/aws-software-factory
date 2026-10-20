import { createSign } from "node:crypto";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const secrets = new SecretsManagerClient({});
const env = process.env;

const b64url = (value) => Buffer.from(value).toString("base64url");

function appJwt(appId, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iat: now - 60, exp: now + 540, iss: String(appId) }));
  const signature = createSign("RSA-SHA256").update(`${header}.${payload}`).sign(privateKey, "base64url");
  return `${header}.${payload}.${signature}`;
}

async function github(method, path, token, body, scheme = "token") {
  const response = await fetch(`https://api.github.com${path}`, {
    method,
    headers: {
      Authorization: `${scheme} ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "massdriver-alarm-to-issue",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok && response.status !== 422) {
    throw new Error(`${method} ${path}: ${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

async function repoToken() {
  const { SecretString } = await secrets.send(new GetSecretValueCommand({ SecretId: env.APP_SECRET_ARN }));
  const app = JSON.parse(SecretString);
  const repoName = env.REPOSITORY.split("/")[1];
  const { token } = await github(
    "POST",
    `/app/installations/${app.installation_id}/access_tokens`,
    appJwt(app.app_id, app.private_key),
    { repositories: [repoName], permissions: { issues: "write" } },
    "Bearer",
  );
  return token;
}

function describe(detail) {
  const region = env.AWS_REGION;
  const name = detail.alarmName;
  const metric = detail.configuration?.metrics?.find((m) => m.metricStat)?.metricStat?.metric;
  const links = [
    `- [CloudWatch alarm](https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#alarmsV2:alarm/${encodeURIComponent(name)})`,
  ];
  const fn = metric?.namespace === "AWS/Lambda" && metric.dimensions?.FunctionName;
  if (fn) {
    const group = encodeURIComponent(encodeURIComponent(`/aws/lambda/${fn}`));
    links.push(`- [Function logs](https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${group})`);
  }
  // Instance names are <project>-<environment>-<component>, and every alarm
  // name starts with its instance's name.
  const [project, environment, component] = name.split("-");
  if (component) {
    links.push(
      `- [Massdriver](https://app.massdriver.cloud/orgs): project \`${project}\`, environment \`${environment}\`, instance \`${project}-${environment}-${component}\`, for its configuration, deployments and runbook`,
    );
  }
  let message = "";
  try {
    message = JSON.parse(detail.configuration?.description || "{}").message || "";
  } catch {
    message = detail.configuration?.description || "";
  }
  const facts = [
    `**Why it fired:** ${detail.state?.reason || "unknown"}`,
    metric && `**Metric:** \`${metric.namespace} ${metric.name}\` ${JSON.stringify(metric.dimensions || {})}`,
    `**Since:** ${detail.state?.timestamp || new Date().toISOString()}`,
  ].filter(Boolean);
  return [message && `> ${message}`, facts.join("\n\n"), `### Look here first\n\n${links.join("\n")}`]
    .filter(Boolean)
    .join("\n\n");
}

export async function handler(event) {
  const detail = event.detail;
  const state = detail?.state?.value;
  if (!detail?.alarmName || !["ALARM", "OK"].includes(state)) return { skipped: true };

  const token = await repoToken();
  const repo = env.REPOSITORY;
  const title = `Alarm: ${detail.alarmName}`;

  await github("POST", `/repos/${repo}/labels`, token, {
    name: "alarm",
    color: "d73a4a",
    description: "Opened by a firing alarm",
  });

  const open = await github("GET", `/repos/${repo}/issues?labels=alarm&state=open&per_page=100`, token);
  const existing = open.find((issue) => issue.title === title && !issue.pull_request);

  if (state === "OK") {
    if (existing) {
      await github("POST", `/repos/${repo}/issues/${existing.number}/comments`, token, {
        body: `Recovered at ${detail.state.timestamp}. Close this once the cause is fixed.`,
      });
    }
    return { recovered: existing?.number ?? null };
  }

  const body = describe(detail);
  if (existing) {
    await github("POST", `/repos/${repo}/issues/${existing.number}/comments`, token, { body: `Fired again.\n\n${body}` });
    return { commented: existing.number };
  }

  const handOff = env.HAND_TO_AGENT === "true";
  const labels = handOff ? ["alarm", "agent"] : ["alarm"];
  const footer = handOff
    ? "The issue agent has picked this up; its pull request will link here."
    : "To have the issue agent attempt a fix, label this issue `agent` or comment `/agent` with any guidance.";
  const issue = await github("POST", `/repos/${repo}/issues`, token, {
    title,
    body: `${body}\n\n---\n${footer}`,
    labels,
  });
  return { opened: issue.number };
}
