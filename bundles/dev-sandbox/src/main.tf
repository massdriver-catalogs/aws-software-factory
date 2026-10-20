data "aws_caller_identity" "current" {}

locals {
  name    = var.md_metadata.name_prefix
  region  = var.network.region
  has_llm = var.llm != null

  instance_types = {
    arm   = { light = "t4g.medium", standard = "t4g.large", heavy = "t4g.xlarge" }
    intel = { light = "t3.medium", standard = "t3.large", heavy = "t3.xlarge" }
  }
  ami_parameter = {
    arm   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
    intel = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  }

  # Pinned to the VPC's first zone so the workspace volume and the VM always
  # land together, whichever network mode is picked.
  zone      = var.network.availability_zones[0]
  subnet_id = one([for s in var.network.subnets : s.id if s.tier == var.network_mode && s.availability_zone_id == local.zone.id])

  key_parameter_name = local.has_llm ? "${var.llm.key_parameter_prefix}/${local.name}" : ""
}

data "aws_ssm_parameter" "ami" {
  name = local.ami_parameter[var.chip]
}

resource "aws_security_group" "sandbox" {
  name        = local.name
  description = "Developer sandbox: nothing inbound"
  vpc_id      = var.network.id

  egress {
    description = "Package registries, git hosts, the AI Platform and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = local.name }
}

resource "aws_ebs_volume" "workspace" {
  availability_zone = local.zone.name
  size              = var.workspace_gb
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "${local.name}-workspace" }
}

resource "aws_instance" "sandbox" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = local.instance_types[var.chip][var.size]
  subnet_id                   = local.subnet_id
  associate_public_ip_address = var.network_mode == "public"
  vpc_security_group_ids      = [aws_security_group.sandbox.id]
  iam_instance_profile        = aws_iam_instance_profile.sandbox.name
  ebs_optimized               = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 16
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/setup.sh.tftpl", {
    region             = local.region
    workspace_device   = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.workspace.id, "-", "")}"
    key_parameter_name = local.key_parameter_name
    base_url           = local.has_llm ? var.llm.base_url : ""
    anthropic_base_url = local.has_llm ? trimsuffix(trimsuffix(var.llm.base_url, "/"), "/v1") : ""
    default_model      = local.has_llm ? var.llm.default_model : ""
    agents             = join(" ", var.agents)
    languages          = join(" ", [for l in var.languages : local.mise_tools[l]])
    dotfiles_repo      = var.dotfiles_repo
    opencode_config    = jsonencode(local.opencode_config)
    claude_settings    = jsonencode(local.claude_settings)
    mass_cli_version   = local.mass_cli_version
    mcp_image          = local.mcp_image
    massdriver_url     = local.massdriver_url
    massdriver_secret  = local.massdriver_secret
    github_secret      = local.github_secret
    github_owner       = local.github_owner
    gh_cli_version     = local.gh_cli_version
    git_name           = local.git_name
    git_email          = local.git_email
  })

  # A new AMI would rebuild the VM on the next unrelated deploy. Upgrades
  # arrive deliberately through a bundle release, which changes user_data.
  lifecycle {
    ignore_changes = [ami]
    precondition {
      condition     = var.network_mode == "public" || var.network.internet_egress
      error_message = "Private network mode needs the VPC's internet egress turned on."
    }
  }

  depends_on = [aws_ssm_parameter.llm_key, aws_secretsmanager_secret_version.github]

  tags = { Name = local.name }
}

resource "aws_volume_attachment" "workspace" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.workspace.id
  instance_id                    = aws_instance.sandbox.id
  stop_instance_before_detaching = true
}

resource "random_password" "llm_key" {
  count   = local.has_llm ? 1 : 0
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "llm_key" {
  count       = local.has_llm ? 1 : 0
  name        = local.key_parameter_name
  description = "AI Platform key for ${local.name}"
  type        = "SecureString"
  value       = random_password.llm_key[0].result
}

resource "aws_ssm_document" "shell" {
  name            = "${local.name}-shell"
  document_type   = "Session"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Shell as the dev user on ${local.name}"
    sessionType   = "Standard_Stream"
    inputs = {
      runAsEnabled = false
      shellProfile = { linux = "exec sudo -iu dev" }
    }
  })
}
