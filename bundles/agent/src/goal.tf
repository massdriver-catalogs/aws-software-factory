locals {
  # Agents run headless around the clock, so the sandbox's interactive extras stay off.
  browser_access = false
  preview_port   = 5173
  dotfiles_repo  = ""
  autonomy       = "free"

  goal       = var.prompt
  goal_every = var.schedule

  goal_minutes   = { once = 0, "5m" = 5, "10m" = 10, "15m" = 15, "1h" = 60, "6h" = 360, "1d" = 1440 }
  goal_recurring = local.goal_every != "once"

  agents     = [var.cli]
  goal_agent = var.cli

  goal_secret = "${local.name}/goal"
}

# Read on every run, so changing the prompt never rebuilds the VM.
resource "aws_secretsmanager_secret" "goal" {
  name                    = local.goal_secret
  description             = "Prompt and schedule for the ${local.name} agent"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "goal" {
  secret_id = aws_secretsmanager_secret.goal.id
  secret_string = jsonencode({
    goal          = local.goal
    every_minutes = local.goal_minutes[local.goal_every]
    agent         = local.goal_agent
    test_goal     = ""
    env           = {}
  })
}
