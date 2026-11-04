# The way in for the people listed in connect_principals: a role they assume
# from their own AWS identity, so no long-lived key exists to leak. It can wake
# this one VM and open a session on it, and nothing else in the account.
locals {
  connect_principals = var.connect_principals == null ? [] : var.connect_principals

  # A role session's ARN names the session rather than the role, and drops the
  # role's path, so it matches the role at the top level or under any path.
  assumed_role = "/^arn:([^:]+):sts::([0-9]{12}):assumed-role/([^/]+)/.*$/"
  connect_patterns = distinct(flatten([
    for arn in local.connect_principals : can(regex(trim(local.assumed_role, "/"), arn)) ? [
      replace(arn, local.assumed_role, "arn:$1:iam::$2:role/$3"),
      replace(arn, local.assumed_role, "arn:$1:iam::$2:role/*/$3"),
    ] : [arn]
  ]))
  connect_accounts = distinct([for arn in local.connect_patterns : "arn:${split(":", arn)[1]}:iam::${split(":", arn)[4]}:root"])
  can_connect      = length(local.connect_patterns) > 0
}

resource "aws_iam_role" "access" {
  count                = local.can_connect ? 1 : 0
  name                 = "${local.name}-access"
  max_session_duration = 43200
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = local.connect_accounts }
      Action    = "sts:AssumeRole"
      Condition = { ArnLike = { "aws:PrincipalArn" = local.connect_patterns } }
    }]
  })
}

resource "aws_iam_role_policy" "access" {
  count = local.can_connect ? 1 : 0
  name  = "connect"
  role  = aws_iam_role.access[0].id
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
        Sid       = "ManageOwnSessions"
        Effect    = "Allow"
        Action    = ["ssm:TerminateSession", "ssm:ResumeSession"]
        Resource  = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/*"
        Condition = { StringLike = { "ssm:resourceTag/aws:ssmmessages:session-id" = ["$${aws:userid}"] } }
      },
    ]
  })
}

resource "massdriver_resource" "access" {
  field = "access"
  name  = "Connect to ${local.name}"
  resource = jsonencode(merge({
    name   = local.name
    region = local.region
    }, local.can_connect ? {
    role_arn = aws_iam_role.access[0].arn
    } : {}, local.browser_access ? {
    browser_url      = "https://${aws_cloudfront_distribution.browser["opencode"].domain_name}"
    preview_url      = "https://${aws_cloudfront_distribution.browser["preview"].domain_name}"
    browser_username = local.browser_username
    browser_password = random_password.browser[0].result
  } : {}))
}
