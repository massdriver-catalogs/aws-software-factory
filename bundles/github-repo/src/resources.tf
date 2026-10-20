resource "massdriver_resource" "repository" {
  field = "repository"
  name  = local.full_name
  resource = jsonencode(merge(
    {
      full_name      = github_repository.main.full_name
      url            = github_repository.main.html_url
      clone_url      = github_repository.main.http_clone_url
      ssh_url        = github_repository.main.ssh_clone_url
      default_branch = var.default_branch
      visibility     = var.visibility
    },
    local.has_registry ? { push_role_arn = aws_iam_role.push[0].arn } : {},
  ))
}
