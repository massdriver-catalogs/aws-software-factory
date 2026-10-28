locals {
  goal       = var.goal == null ? "" : var.goal
  goal_every = coalesce(var.goal_every, "once")

  goal_minutes   = { once = 0, "5m" = 5, "10m" = 10, "15m" = 15, "1h" = 60, "6h" = 360, "1d" = 1440 }
  goal_recurring = local.goal != "" && local.goal_every != "once"

  agents     = var.agents
  goal_agent = contains(local.agents, "claude-code") ? "claude-code" : "opencode"

  goal_secret = "${local.name}/goal"
}

# Read on every run, so changing the goal never rebuilds the VM.
resource "aws_secretsmanager_secret" "goal" {
  name                    = local.goal_secret
  description             = "Standing goal for the ${local.name} sandbox's agent"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "goal" {
  secret_id = aws_secretsmanager_secret.goal.id
  secret_string = jsonencode({
    goal          = local.goal
    every_minutes = local.goal_minutes[local.goal_every]
    agent         = local.goal_agent
  })

  lifecycle {
    precondition {
      condition     = contains(keys(local.goal_minutes), local.goal_every)
      error_message = "Work on the goal must be one of once, 5m, 10m, 15m, 1h, 6h or 1d."
    }
  }
}

locals {
  aws_access_policies = {
    none      = []
    observe   = ["arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess", "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"]
    read_only = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  }
}

resource "aws_iam_role_policy_attachment" "aws_access" {
  for_each   = toset(local.aws_access_policies[coalesce(var.aws_access, "none")])
  role       = aws_iam_role.sandbox.name
  policy_arn = each.key
}
