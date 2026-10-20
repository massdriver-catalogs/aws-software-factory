# GitHub Actions OIDC

An AWS account trusts GitHub Actions' identity tokens through one OIDC provider. With it in place, a workflow exchanges its token for short-lived credentials on a role that names the exact repository and branch allowed to assume it. No AWS keys are stored in GitHub.

AWS allows one provider per issuer per account, so this is deployed once and shared. Repositories never create their own; each GitHub Repository bundle creates a role that trusts this provider.
