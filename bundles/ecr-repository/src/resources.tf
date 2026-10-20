# Consumers bind access by attaching one of these policy ARNs to their own
# role (aws_iam_role_policy_attachment), so the repository owns its permissions.
resource "massdriver_resource" "repository" {
  field = "repository"
  name  = "ECR ${local.name}"
  resource = jsonencode({
    name        = aws_ecr_repository.main.name
    arn         = aws_ecr_repository.main.arn
    url         = aws_ecr_repository.main.repository_url
    region      = var.region
    registry_id = aws_ecr_repository.main.registry_id
    policies = [
      { name = "push", arn = aws_iam_policy.push.arn },
      { name = "pull", arn = aws_iam_policy.pull.arn },
    ]
  })
}
