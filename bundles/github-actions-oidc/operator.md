---
templating: mustache
---
# GitHub Actions OIDC

## Deploy fails with EntityAlreadyExists

The account already has a GitHub OIDC provider, created by hand or by another tool. Delete it if nothing else uses it, or import it into this instance's state, then redeploy:

```bash
aws iam list-open-id-connect-providers
```

## A workflow fails with "Not authorized to perform sts:AssumeRoleWithWebIdentity"

The provider is fine; the role's trust policy doesn't match the workflow. See the repository's runbook: the role only trusts its own repository's default branch.
