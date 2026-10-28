locals {
  mass_cli_version = "2.5.0"
  mcp_image        = "docker.io/massdrivercloud/mcp-server:0.2.0"

  # Empty until @massdriver/opencode is on npm; once set, the plugin registers
  # the MCP server itself, so the direct mcp entry below is dropped.
  opencode_plugin_spec = ""

  massdriver_url    = try(regex("^https?://[^/]+", var.md_metadata.observability.alarm_webhook_url), "https://api.massdriver.cloud")
  massdriver_secret = "${local.name}/massdriver-api-key"

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
      # A headless run that hits a question auto-rejects it and stops.
      external_directory = local.opencode_permission
    }
    plugin = local.opencode_plugin_spec != "" ? [local.opencode_plugin_spec] : null
    mcp = local.opencode_plugin_spec == "" ? {
      massdriver = {
        type    = "local"
        command = ["docker", "run", "-i", "--rm", "-e", "MASSDRIVER_API_KEY", "-e", "MASSDRIVER_ORGANIZATION_ID", "-e", "MASSDRIVER_URL", local.mcp_image]
        enabled = false
        timeout = 30000
      }
    } : null
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
