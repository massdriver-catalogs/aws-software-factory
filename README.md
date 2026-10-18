# AWS Software Factory

A Massdriver catalog for running an agentic software factory in your own AWS account: a private open-weight model, an isolated VM where coding agents work, and the platform their apps ship onto. Code lives in GitHub. Agents get no cloud credentials — every infrastructure change goes through Massdriver, under the same policy and approvals as a person.

## What it builds

| Layer | Purpose |
|---|---|
| Foundation | Network, container registry, GitHub repository with its build pipeline |
| Model | An OpenAI-compatible endpoint backed by a GPU you run (vLLM on EC2) or by Bedrock |
| Agent sandbox | A disposable VM running opencode and other coding agents, reached through the browser or SSM, with no inbound ports |
| Apps | Functions and HTTP APIs, tables, buckets, static sites, sign-in, secrets |
| Factory | In-account GitHub Actions runners for issue → pull request agents, code review and CI; release to dev on merge |
| Feedback | Alarms open GitHub issues; budget alerts |

Bundles connect through resource types, so a layer can change underneath without touching what depends on it. Moving the sandbox from Bedrock to a self-hosted GPU is a change to the model, not the sandbox.

## Layout

```
platforms/        Credential types (AWS, GitHub)
resource-types/   Contracts between bundles
bundles/          OpenTofu bundles
```

## Getting started

1. Add a `MASSDRIVER_API_KEY` secret (a service account key) and a `MASSDRIVER_ORG_ID` variable to the repository. Every push to `main` publishes what changed; **Actions → Publish → Run workflow** with *all* publishes everything.
2. In Massdriver, add your AWS account under **Credentials** using the AWS IAM Role instructions.

## Versioning

Everything publishes as `0.0.0`, which can be republished in place for bundles and resource types alike. Publishing any other version to a repository ends that: once a repository holds a real version, `0.0.0` can no longer be overwritten there.
