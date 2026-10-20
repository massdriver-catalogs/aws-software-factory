data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals {
  name    = var.md_metadata.name_prefix
  region  = var.network.region
  account = data.aws_caller_identity.current.account_id
  has_llm = var.llm != null

  # Bump deliberately: runners register with --disableupdate so a job never
  # races a self-update, which means GitHub's minimum version moves past this.
  runner_version = "2.338.0"

  instance_types = {
    small  = "t4g.small"
    medium = "t4g.medium"
    large  = "t4g.large"
  }

  labels          = distinct(concat(["self-hosted", "linux", "arm64", "factory", local.name], var.extra_labels))
  token_parameter = "/${local.name}/registration-token"
  key_parameter   = local.has_llm ? "${var.llm.key_parameter_prefix}/${local.name}" : ""

  private_subnets = [for s in var.network.subnets : s.id if s.tier == "private"]

  job_env = join("\n", concat(
    ["AGENT_TOKEN_URL=${aws_lambda_function_url.agent_token.function_url}"],
    local.has_llm ? [
      "OPENAI_BASE_URL=${var.llm.base_url}",
      "OPENAI_API_KEY=${random_password.llm_key[0].result}",
      "OPENAI_MODEL=${var.llm.default_model}",
    ] : [],
  ))
}

resource "random_password" "llm_key" {
  count   = local.has_llm ? 1 : 0
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "llm_key" {
  count       = local.has_llm ? 1 : 0
  name        = local.key_parameter
  description = "AI Platform key for ${local.name}"
  type        = "SecureString"
  value       = random_password.llm_key[0].result
}

resource "aws_security_group" "runner" {
  name        = local.name
  description = "GitHub runners: outbound only"
  vpc_id      = var.network.id

  egress {
    description = "GitHub, package registries, AWS APIs and the AI Platform"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = local.name }
}

resource "aws_iam_role" "runner" {
  name = "${local.name}-runner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "runner_ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The runner can read the short-lived registration token and its gateway key,
# and nothing else; the GitHub App key never reaches the VM.
resource "aws_iam_role_policy" "runner" {
  name = "registration"
  role = aws_iam_role.runner.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = concat(
          ["arn:aws:ssm:${local.region}:${local.account}:parameter${local.token_parameter}"],
          aws_ssm_parameter.llm_key[*].arn,
        )
      },
      {
        Effect    = "Allow"
        Action    = "kms:Decrypt"
        Resource  = "*"
        Condition = { StringEquals = { "kms:ViaService" = "ssm.${local.region}.amazonaws.com" } }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "runner" {
  name = "${local.name}-runner"
  role = aws_iam_role.runner.name
}

resource "aws_instance" "runner" {
  count                  = var.runner_count
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = local.instance_types[var.size]
  subnet_id              = local.private_subnets[count.index % length(local.private_subnets)]
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  ebs_optimized          = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.disk_gb
  }

  maintenance_options {
    auto_recovery = "default"
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/setup.sh.tftpl", {
    region          = local.region
    organization    = var.github.owner
    name_prefix     = local.name
    labels          = join(",", local.labels)
    token_parameter = local.token_parameter
    runner_version  = local.runner_version
    job_env         = local.job_env
  })

  lifecycle {
    ignore_changes = [ami]
    precondition {
      condition     = var.network.internet_egress
      error_message = "Runners live in private subnets and need the VPC's internet egress to reach GitHub. Turn egress on in the shared VPC."
    }
  }

  # A runner that boots before the first token exists only waits and retries,
  # but starting after it keeps the first registration quick.
  depends_on = [aws_lambda_invocation.first_token]

  tags = { Name = "${local.name}-${count.index}" }
}
