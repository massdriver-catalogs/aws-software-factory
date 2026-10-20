resource "github_issue_label" "agent" {
  count       = local.factory ? 1 : 0
  repository  = github_repository.main.name
  name        = "agent"
  color       = "8957e5"
  description = "Hand this issue to the coding agent"
}

# The agent token service only answers runs of a workflow named agent.yml, so
# the file name is part of the contract with the Software Factory's runners.
resource "github_repository_file" "factory" {
  for_each = local.factory ? toset(["agent.yml", "ai-review.yml"]) : toset([])

  repository          = github_repository.main.name
  branch              = var.default_branch
  file                = ".github/workflows/${each.key}"
  content             = file("${path.module}/starter/${each.key}")
  commit_message      = "Add the ${each.key} workflow"
  overwrite_on_create = false

  lifecycle {
    ignore_changes = [content, commit_message, commit_author, commit_email]
  }

  depends_on = [github_repository_file.starter, github_branch_default.main]
}
