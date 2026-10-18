data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "gateway" {
  name        = "${local.name}-gateway"
  description = "LLM gateway: OpenAI-compatible API for the VPC"
  vpc_id      = var.network.id

  ingress {
    description = "Gateway API from the VPC"
    from_port   = local.port
    to_port     = local.port
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }

  egress {
    description = "Bedrock, model servers and package downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "model_server_from_gateway" {
  count                        = local.has_model_server ? 1 : 0
  security_group_id            = var.model_server.security_group_id
  referenced_security_group_id = aws_security_group.gateway.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  description                  = "Model API from the ${local.name} gateway only"
}

resource "aws_iam_role" "gateway" {
  name = "${local.name}-gateway"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gateway_ssm" {
  role       = aws_iam_role.gateway.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "gateway" {
  name = "gateway"
  role = aws_iam_role.gateway.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeBedrockModels"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = length(local.bedrock_arns) > 0 ? local.bedrock_arns : ["arn:aws:bedrock:${local.region}::foundation-model/none"]
      },
      {
        Sid      = "ReadConsumerKeysAndConfig"
        Effect   = "Allow"
        Action   = ["ssm:GetParametersByPath", "ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}/*"]
      },
      {
        Sid      = "DecryptSecureStrings"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "ssm.${local.region}.amazonaws.com" }
        }
      },
      {
        Sid      = "ReadMasterKey"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.master_key.arn
      },
      {
        Sid      = "WriteLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.gateway.arn}:*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "gateway" {
  name = "${local.name}-gateway"
  role = aws_iam_role.gateway.name
}

resource "aws_instance" "gateway" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = "t4g.small"
  subnet_id              = local.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.gateway.id]
  iam_instance_profile   = aws_iam_instance_profile.gateway.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 20
  }

  maintenance_options {
    auto_recovery = "default"
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region         = local.region
    port           = local.port
    key_prefix     = local.key_prefix
    config_param   = local.config_param
    master_key_arn = aws_secretsmanager_secret.master_key.arn
    log_group      = aws_cloudwatch_log_group.gateway.name
    custom_auth    = file("${path.module}/templates/custom_auth.py")
  })
  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${local.name}-gateway" }
}
