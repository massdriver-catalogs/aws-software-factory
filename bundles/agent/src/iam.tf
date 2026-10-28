resource "aws_iam_role" "sandbox" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.sandbox.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "own_secrets" {
  name = "own-secrets"
  role = aws_iam_role.sandbox.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:${local.name}/*"
      }],
      [for arn in aws_ssm_parameter.llm_key[*].arn : {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = arn
      }],
      [for arn in aws_ssm_parameter.llm_key[*].arn : {
        Effect    = "Allow"
        Action    = "kms:Decrypt"
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "ssm.${local.region}.amazonaws.com" } }
      }],
    )
  })
}

resource "aws_iam_instance_profile" "sandbox" {
  name = local.name
  role = aws_iam_role.sandbox.name
}
