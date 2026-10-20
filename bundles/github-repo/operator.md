---
templating: mustache
---
# GitHub Repository

{{#resources.repository}}
## See recent builds

```bash
gh run list -R {{resources.repository.full_name}} --workflow build.yml --limit 5
gh run view -R {{resources.repository.full_name}} --log-failed
```
{{/resources.repository}}

## The workflow didn't run

- **Actions disabled:** the organization or repository has Actions turned off. Settings → Actions → General.
- **The workflow file was removed or renamed:** it must be `.github/workflows/*.yml` on the default branch.
- **Pushed to another branch:** only the default branch pushes images; other branches build only through pull requests.

## The build failed before pushing

Open the failed run and check which job stopped:

- **test:** a pytest failure. Run `pytest -q` locally to reproduce.
- **secrets:** gitleaks found something that looks like a credential, in the current files or anywhere in history. Revoke the credential first; removing it from the code doesn't un-leak it. A false positive can be allowed with a `.gitleaksignore` entry holding the finding's fingerprint from the log.
- **Scan the image:** Trivy found a critical vulnerability with a fix available. Rebuilding usually pulls the patched base image; otherwise bump the base image tag in the Dockerfile.

## "Not authorized to perform sts:AssumeRoleWithWebIdentity"

The role only trusts `repo:<owner>/<name>:ref:refs/heads/{{params.default_branch}}`. Builds from forks, tags or other branches can't assume it. If the repository was renamed or transferred, the trust no longer matches: redeploy this bundle.

If the job never got a token at all, the workflow is missing `permissions: id-token: write`.

## Push denied by ECR

- **`tag invalid` or `already exists`:** the container repository has immutable tags and this commit was already pushed. Re-running the same commit can't push again; push a new commit.
- **`not authorized to perform ecr:...`:** the role's push policy no longer matches the container repository. Redeploy this bundle so it reattaches the current policy.

## The image builds but Lambda rejects it

Lambda needs a single-platform arm64 image. Keep `platforms: linux/arm64` and `provenance: false` in the workflow.

## Deploy fails: name already exists

Another repository in the organization, possibly an archived one from an earlier deploy, has the name **{{params.repository_name}}**. Delete or rename it on GitHub, or pick a different name.

## Deploy fails with 403 from GitHub

The GitHub App lacks a permission or isn't installed on all repositories. Check the app's permissions against the GitHub App credential's instructions, then **Install App → All repositories**.
