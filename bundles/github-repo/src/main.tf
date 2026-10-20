locals {
  name         = var.md_metadata.name_prefix
  has_registry = var.registry != null
  full_name    = "${var.github.owner}/${var.repository_name}"
}

resource "github_repository" "main" {
  name                   = var.repository_name
  description            = var.description
  visibility             = var.visibility
  auto_init              = true
  has_issues             = true
  delete_branch_on_merge = true

  # Decommissioning archives the repository instead of deleting the code.
  archive_on_destroy = true

  lifecycle {
    precondition {
      condition     = !local.has_registry || var.github_oidc != null
      error_message = "Pushing to ECR needs GitHub Actions OIDC. Deploy the GitHub Actions OIDC bundle once and set it as this environment's default."
    }
  }
}

resource "github_repository_vulnerability_alerts" "main" {
  repository = github_repository.main.name
  enabled    = true
}

# auto_init creates main; any other default branch is cut from it.
resource "github_branch" "default" {
  count      = var.default_branch == "main" ? 0 : 1
  repository = github_repository.main.name
  branch     = var.default_branch
}

resource "github_branch_default" "main" {
  repository = github_repository.main.name
  branch     = var.default_branch
  depends_on = [github_branch.default]
}

resource "github_repository_file" "starter" {
  for_each = var.seed_starter_files ? {
    "Dockerfile"    = file("${path.module}/starter/Dockerfile")
    "app.py"        = file("${path.module}/starter/app.py")
    "test_app.py"   = file("${path.module}/starter/test_app.py")
    ".dockerignore" = file("${path.module}/starter/dockerignore")
  } : {}

  repository          = github_repository.main.name
  branch              = var.default_branch
  file                = each.key
  content             = each.value
  commit_message      = "Add ${each.key}"
  overwrite_on_create = false

  # Written once; after the first commit the team owns these files.
  lifecycle {
    ignore_changes = [content, commit_message, commit_author, commit_email]
  }

  depends_on = [github_branch_default.main]
}

# Committed last, so the first build sees the whole app; the variables must
# already exist or that build won't push.
resource "github_repository_file" "workflow" {
  count = var.seed_starter_files ? 1 : 0

  repository          = github_repository.main.name
  branch              = var.default_branch
  file                = ".github/workflows/build.yml"
  content             = templatefile("${path.module}/starter/build.yml.tftpl", { branch = var.default_branch })
  commit_message      = "Add the build workflow"
  overwrite_on_create = false

  lifecycle {
    ignore_changes = [content, commit_message, commit_author, commit_email]
  }

  depends_on = [github_repository_file.starter, github_actions_variable.push]
}

moved {
  from = github_repository_file.starter[".github/workflows/build.yml"]
  to   = github_repository_file.workflow[0]
}
