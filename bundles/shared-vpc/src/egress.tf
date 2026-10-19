locals {
  nat_gateway_count = var.egress == "nat_gateway_per_zone" ? var.zone_count : (var.egress == "nat_gateway" ? 1 : 0)
  nat_instance      = var.egress == "nat_instance"
}

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-${local.zone_ids[count.index]}" }
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${local.name}-${local.zone_ids[count.index]}" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route" "private_nat_gateway" {
  count                  = local.nat_gateway_count > 0 ? var.zone_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[min(count.index, local.nat_gateway_count - 1)].id
}

data "aws_ssm_parameter" "al2023_arm64" {
  count = local.nat_instance ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "nat" {
  count       = local.nat_instance ? 1 : 0
  name        = "${local.name}-nat"
  description = "NAT instance: forward traffic from the VPC to the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Traffic from the VPC to forward"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr]
  }

  egress {
    description = "Forwarded traffic to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "nat" {
  count = local.nat_instance ? 1 : 0
  name  = "${local.name}-nat"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nat_ssm" {
  count      = local.nat_instance ? 1 : 0
  role       = aws_iam_role.nat[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat" {
  count = local.nat_instance ? 1 : 0
  name  = "${local.name}-nat"
  role  = aws_iam_role.nat[0].name
}

resource "aws_instance" "nat" {
  count                       = local.nat_instance ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_arm64[0].value
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  source_dest_check           = false
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  iam_instance_profile        = aws_iam_instance_profile.nat[0].name
  ebs_optimized               = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  maintenance_options {
    auto_recovery = "default"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    for _ in $(seq 1 30); do dnf install -y iptables-services && break; sleep 10; done
    rpm -q iptables-services
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/90-nat.conf
    sysctl -p /etc/sysctl.d/90-nat.conf
    IFACE=$(ip route show default | awk '{print $5; exit}')
    iptables -F
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables
  EOF

  # A new AMI would replace the instance and drop egress mid-deploy. Patching
  # happens through SSM; replace deliberately with `tofu taint`.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${local.name}-nat" }
}

resource "aws_route" "private_nat_instance" {
  count                  = local.nat_instance ? var.zone_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}
