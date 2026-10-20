# The developer's way in. It can wake this one sandbox and open an SSH
# session on it through Session Manager, and nothing else in the account.
resource "aws_iam_user" "access" {
  name = "${local.name}-access"
}

resource "aws_iam_access_key" "access" {
  user = aws_iam_user.access.name
}

resource "aws_iam_user_policy" "access" {
  name = "connect"
  user = aws_iam_user.access.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FindSandbox"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ssm:DescribeInstanceInformation"]
        Resource = "*"
      },
      {
        Sid      = "WakeSandbox"
        Effect   = "Allow"
        Action   = "ec2:StartInstances"
        Resource = aws_instance.sandbox.arn
      },
      {
        Sid       = "PushShortLivedKey"
        Effect    = "Allow"
        Action    = "ec2-instance-connect:SendSSHPublicKey"
        Resource  = aws_instance.sandbox.arn
        Condition = { StringEquals = { "ec2:osuser" = "dev" } }
      },
      {
        Sid    = "OpenSession"
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          aws_instance.sandbox.arn,
          "arn:aws:ssm:${local.region}::document/AWS-StartSSHSession",
          aws_ssm_document.shell.arn,
        ]
      },
      {
        Sid      = "ManageOwnSessions"
        Effect   = "Allow"
        Action   = ["ssm:TerminateSession", "ssm:ResumeSession"]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*"
      },
    ]
  })
}

resource "massdriver_resource" "access" {
  field = "access"
  name  = "Connect to ${local.name}"
  resource = jsonencode(merge({
    name              = local.name
    region            = local.region
    access_key_id     = aws_iam_access_key.access.id
    secret_access_key = aws_iam_access_key.access.secret
    }, var.browser_access ? {
    browser_url      = "https://${aws_cloudfront_distribution.browser["opencode"].domain_name}"
    preview_url      = "https://${aws_cloudfront_distribution.browser["preview"].domain_name}"
    browser_username = local.browser_username
    browser_password = random_password.browser[0].result
  } : {}))
}
