# Only a first deploy can adopt: once the repository is in state this block
# does nothing, so flipping the toggle later changes nothing.
import {
  for_each = var.adopt_existing_repository ? toset([var.repository_name]) : toset([])
  to       = github_repository.main
  id       = each.value
}
