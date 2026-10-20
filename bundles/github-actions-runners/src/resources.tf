resource "massdriver_resource" "runners" {
  field = "runners"
  name  = "GitHub runners ${local.name}"
  resource = jsonencode({
    organization    = var.github.owner
    labels          = local.labels
    runner_group    = "Default"
    has_ai_platform = local.has_llm
  })
}
