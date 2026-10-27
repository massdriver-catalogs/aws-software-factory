data "aws_caller_identity" "current" {}

locals {
  name       = var.md_metadata.name_prefix
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "reports" {
  provider      = aws.bucket
  bucket        = "${local.name}-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "reports" {
  provider                = aws.bucket
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "reports" {
  provider = aws.bucket
  bucket   = aws_s3_bucket.reports.id
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = aws_s3_bucket.reports.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      },
      {
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.reports.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.reports]
}

resource "aws_cur_report_definition" "massdriver" {
  report_name                = local.name
  time_unit                  = "DAILY"
  format                     = "textORcsv"
  compression                = "ZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = aws_s3_bucket.reports.bucket
  s3_prefix                  = "reports"
  s3_region                  = var.bucket_region
  report_versioning          = "OVERWRITE_REPORT"

  depends_on = [aws_s3_bucket_policy.reports]
}

# Billing setting; only the management (payer) account can apply it.
resource "aws_ce_cost_allocation_tag" "md_package" {
  count   = var.activate_cost_allocation_tag ? 1 : 0
  tag_key = "md-package"
  status  = "Active"
}

# Massdriver's cost collector takes access keys, not a role.
resource "aws_iam_user" "collector" {
  name = local.name
}

resource "aws_iam_user_policy" "collector" {
  name = "read-cost-reports"
  user = aws_iam_user.collector.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:HeadBucket", "s3:ListBucket"], Resource = aws_s3_bucket.reports.arn },
      { Effect = "Allow", Action = "s3:GetObject", Resource = "${aws_s3_bucket.reports.arn}/*" },
      { Effect = "Allow", Action = "tag:GetResources", Resource = "*" },
    ]
  })
}

resource "aws_iam_access_key" "collector" {
  user = aws_iam_user.collector.name
}

resource "aws_secretsmanager_secret" "integration" {
  name                    = "${local.name}/integration"
  description             = "Values for Massdriver's AWS Cost and Usage Reports integration"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "integration" {
  secret_id = aws_secretsmanager_secret.integration.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.collector.id
    secret_access_key = aws_iam_access_key.collector.secret
    bucket_name       = aws_s3_bucket.reports.bucket
    bucket_region     = var.bucket_region
  })
}
