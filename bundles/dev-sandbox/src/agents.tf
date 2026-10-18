locals {
  mise_tools = {
    python = "python@3.12"
    node   = "node@lts"
    go     = "go@latest"
    java   = "java@temurin-21"
    rust   = "rust@stable"
  }

  opencode_permission = var.autonomy == "free" ? "allow" : "ask"

  opencode_settings = {
    "$schema" = "https://opencode.ai/config.json"
    permission = {
      edit     = local.opencode_permission
      bash     = local.opencode_permission
      webfetch = local.opencode_permission
    }
    model = try("aiplatform/${var.llm.default_model}", null)
    provider = try({
      aiplatform = {
        npm  = "@ai-sdk/openai-compatible"
        name = "AI Platform"
        options = {
          baseURL = var.llm.base_url
          apiKey  = "{env:AIPLATFORM_API_KEY}"
        }
        models = { for m in var.llm.models : m => { name = m } }
      }
    }, null)
  }
  opencode_config = { for k, v in local.opencode_settings : k => v if v != null }

  claude_settings = {
    for k, v in { permissions = { defaultMode = "bypassPermissions" } } : k => v if var.autonomy == "free"
  }
}
