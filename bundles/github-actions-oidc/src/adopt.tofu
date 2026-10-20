data "aws_caller_identity" "current" {}

# Only a first deploy can adopt: once the provider is in state this block does
# nothing, so flipping the toggle later changes nothing.
import {
  for_each = var.adopt_existing_provider ? toset(["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]) : toset([])
  to       = aws_iam_openid_connect_provider.github
  id       = each.value
}
