# TODO

## Software factory

- [ ] Factory runners: GitHub Actions runners in the account, on the VPC's private subnets, reaching the AI Platform without cloud keys in GitHub
- [ ] Issue → PR agent: label an issue, a headless opencode run on a runner opens a pull request
- [ ] AI code review on pull requests, against the AI Platform
- [ ] CI on the app repo: build, test, image scan, secret scan
- [ ] Release to dev: after a merge, the pipeline deploys the new image to the dev environment with a scoped Massdriver token; production goes through approval
- [ ] Alarm → GitHub issue: app alarms open an issue with context from the context engine, which the issue → PR agent can pick up
- [ ] Budget guard: AWS Budget with alerts, on the canvas
- [ ] Workshop scope: the factory is the point of the workshop, so it runs live, not as take-home

## Citizen dev platform

- [ ] Connect the GitHub App credential
- [ ] GitHub repository bundle with an arm64 build pipeline that pushes to ECR
- [ ] ECR repository bundle
- [ ] Landing zone: a team's non-negotiables (network, third-party keys, …)
- [ ] Sign-in (Cognito), and route authorization on the HTTP API
- [ ] Static site (S3 + CloudFront)
- [ ] App secrets (Secrets Manager)
- [ ] Lambda: optional connection to the AI Platform (VPC + gateway key)
- [ ] `dns-zone` resource type for custom domains

## Developer sandbox

- [ ] Browser access: opencode web through CloudFront, plus an app preview URL
- [ ] GitHub access from the sandbox, through the GitHub App
- [ ] Private dotfiles (#1)
- [ ] Tailscale (#2)

## AI Platform

- [ ] Per-key usage and budgets on the gateway
- [ ] Stage model weights in S3 so the GPU's first boot doesn't pull everything through the NAT instance

## Later

- [ ] CodeCommit + CodeBuild alternative that produces `source-repository`
- [ ] `agent-sandbox` resource so dev data bundles can grant a sandbox access

## Cleanup

- [ ] Delete the stale `landing-zone` and `aws-landing-zone` repositories from the catalog
- [ ] Keep or decommission the `Todo App` test project
- [ ] Review the gateway endpoint grant to all environments
- [ ] Remove the leftover agent worktrees in `.claude/worktrees`
