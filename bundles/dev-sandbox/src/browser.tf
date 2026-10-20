locals {
  browser_username = "opencode"
  browser_targets  = var.browser_access ? { opencode = 4096, preview = var.preview_port } : {}

  # CloudFront reaches an EC2 VPC origin by its private IP DNS name, which
  # survives a reboot; the instance ARN in the VPC origin is what follows it.
  private_ip_dns = local.region == "us-east-1" ? "ip-${replace(aws_instance.sandbox.private_ip, ".", "-")}.ec2.internal" : "ip-${replace(aws_instance.sandbox.private_ip, ".", "-")}.${local.region}.compute.internal"
}

resource "random_password" "browser" {
  count   = var.browser_access ? 1 : 0
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "browser" {
  count                   = var.browser_access ? 1 : 0
  name                    = "${local.name}/browser-password"
  description             = "Password for ${local.name}'s browser access"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "browser" {
  count         = var.browser_access ? 1 : 0
  secret_id     = aws_secretsmanager_secret.browser[0].id
  secret_string = random_password.browser[0].result
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.browser_access ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "browser" {
  for_each          = local.browser_targets
  security_group_id = aws_security_group.sandbox.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  description       = "CloudFront to ${each.key}"
}

resource "aws_cloudfront_vpc_origin" "browser" {
  for_each = local.browser_targets

  vpc_origin_endpoint_config {
    name                   = "${local.name}-${each.key}-${aws_instance.sandbox.id}"
    arn                    = aws_instance.sandbox.arn
    http_port              = each.value
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  # A VPC origin can't change while a distribution uses it, so a rebuilt VM
  # gets a new one and the distribution moves over before the old one goes.
  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [aws_instance.sandbox.id]
  }
}

data "aws_cloudfront_cache_policy" "disabled" {
  count = var.browser_access ? 1 : 0
  name  = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  count = var.browser_access ? 1 : 0
  name  = "Managed-AllViewerExceptHostHeader"
}

# The dev server has no login of its own, so the preview checks the same
# credentials as opencode before anything reaches the sandbox.
resource "aws_cloudfront_function" "preview_auth" {
  count   = var.browser_access ? 1 : 0
  name    = "${local.name}-preview-auth"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var auth = event.request.headers.authorization;
      if (auth && auth.value === "Basic ${base64encode("${local.browser_username}:${random_password.browser[0].result}")}") {
        return event.request;
      }
      return {
        statusCode: 401,
        statusDescription: "Unauthorized",
        headers: { "www-authenticate": { value: "Basic realm=\"${local.name} preview\"" } }
      };
    }
  JS
}

resource "aws_cloudfront_distribution" "browser" {
  for_each = local.browser_targets

  enabled      = true
  comment      = "${local.name} ${each.key}"
  price_class  = "PriceClass_100"
  http_version = "http2"

  origin {
    origin_id   = "sandbox"
    domain_name = local.private_ip_dns

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.browser[each.key].id
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }
  }

  default_cache_behavior {
    target_origin_id         = "sandbox"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = false
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled[0].id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer[0].id

    dynamic "function_association" {
      for_each = each.key == "preview" ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.preview_auth[0].arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
