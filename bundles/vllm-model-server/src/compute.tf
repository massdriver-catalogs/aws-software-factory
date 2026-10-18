resource "aws_security_group" "server" {
  name        = "${local.name}-vllm"
  description = "Model server: ingress is added by the LLM gateway only"
  vpc_id      = var.network.id

  egress {
    description = "Model downloads and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # The gateway adds its own ingress rule to this group.
  lifecycle {
    ignore_changes = [ingress]
  }
}

resource "aws_iam_role" "server" {
  name = "${local.name}-vllm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "server" {
  name = "vllm"
  role = aws_iam_role.server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.api_key.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.server.arn}:*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "server" {
  name = "${local.name}-vllm"
  role = aws_iam_role.server.name
}

resource "aws_instance" "server" {
  ami                    = data.aws_ssm_parameter.gpu_ami.value
  instance_type          = var.instance_type
  subnet_id              = local.private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 120
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region        = local.region
    port          = local.port
    secret_arn    = aws_secretsmanager_secret.api_key.arn
    log_group     = aws_cloudwatch_log_group.server.name
    repo          = local.model.repo
    served_name   = var.model
    max_model_len = local.model.max_model_len
    tool_parser   = local.model.tool_parser
  })
  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = data.aws_servicequotas_service_quota.gpu_vcpus.value >= 4
      error_message = "This AWS account's quota for \"Running On-Demand G and VT instances\" in ${local.region} is ${data.aws_servicequotas_service_quota.gpu_vcpus.value} vCPUs; a GPU server needs 4. Request an increase in Service Quotas (EC2), or use Bedrock models on the LLM gateway instead."
    }
    precondition {
      condition     = local.gpu_gb[var.instance_type] >= local.model.min_gpu_gb
      error_message = "${var.model} needs a GPU with at least ${local.model.min_gpu_gb} GB. Pick g6e.xlarge."
    }
    precondition {
      condition     = length(local.private_subnets) > 0
      error_message = "${var.instance_type} isn't offered in any of the VPC's availability zones. Pick another GPU."
    }
  }

  tags = { Name = "${local.name}-vllm" }
}
