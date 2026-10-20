# Pipelines bind publish access by attaching the policy ARN to their own role
# (aws_iam_role_policy_attachment), so the site owns its permissions.
resource "massdriver_resource" "site" {
  field = "site"
  name  = "Static site ${local.name}"
  resource = jsonencode({
    url             = "https://${aws_cloudfront_distribution.site.domain_name}"
    bucket          = aws_s3_bucket.site.id
    distribution_id = aws_cloudfront_distribution.site.id
    policies = [
      { name = "publish", arn = aws_iam_policy.publish.arn },
    ]
  })
}
