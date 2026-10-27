locals {
  # An application on this runtime defines its agent through app envs:
  # AGENT_GOAL, AGENT_GOAL_EVERY and AGENT_CLI. A goal typed into the form
  # replaces the application's, schedule included.
  app_env = try(jsondecode(file("/massdriver/envs.json")), {})

  form_goal  = var.goal == null ? "" : var.goal
  goal       = local.form_goal != "" ? local.form_goal : try(local.app_env.AGENT_GOAL, "")
  goal_every = local.form_goal != "" ? coalesce(var.goal_every, "once") : try(local.app_env.AGENT_GOAL_EVERY, "once")

  goal_minutes   = { once = 0, "15m" = 15, "1h" = 60, "6h" = 360, "1d" = 1440 }
  goal_recurring = local.goal != "" && local.goal_every != "once"

  app_agent  = try(local.app_env.AGENT_CLI, "")
  agents     = distinct(concat(var.agents, local.app_agent != "" ? [local.app_agent] : []))
  goal_agent = local.app_agent != "" ? local.app_agent : (contains(local.agents, "claude-code") ? "claude-code" : "opencode")

  goal_secret = "${local.name}/goal"
}

# Read on every run, so changing the goal never rebuilds the VM.
resource "aws_secretsmanager_secret" "goal" {
  name                    = local.goal_secret
  description             = "Standing goal and app environment for the ${local.name} sandbox's agent"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "goal" {
  secret_id = aws_secretsmanager_secret.goal.id
  secret_string = jsonencode({
    goal          = local.goal
    every_minutes = local.goal_minutes[local.goal_every]
    agent         = local.goal_agent
    env           = { for k, v in local.app_env : k => tostring(v) if !contains(["AGENT_GOAL", "AGENT_GOAL_EVERY", "AGENT_CLI"], k) }
  })

  lifecycle {
    precondition {
      condition     = contains(keys(local.goal_minutes), local.goal_every)
      error_message = "AGENT_GOAL_EVERY must be one of once, 15m, 1h, 6h or 1d."
    }
    precondition {
      condition     = contains(["opencode", "claude-code"], local.goal_agent)
      error_message = "AGENT_CLI must be opencode or claude-code."
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
