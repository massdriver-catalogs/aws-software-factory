locals {
  mass_cli_version = "2.5.0"
  mcp_image        = "docker.io/massdrivercloud/mcp-server:0.2.0"

  massdriver_url    = try(regex("^https?://[^/]+", var.md_metadata.observability.alarm_webhook_url), "https://api.massdriver.cloud")
  massdriver_secret = "${local.name}/massdriver-api-key"

  mise_tools = {
    python = "python@3.12"
    node   = "node@lts"
    go     = "go@latest"
    java   = "java@temurin-21"
    rust   = "rust@stable"
  }

  opencode_permission = local.autonomy == "free" ? "allow" : "ask"

  opencode_settings = {
    "$schema" = "https://opencode.ai/config.json"
    permission = {
      edit     = local.opencode_permission
      bash     = local.opencode_permission
      webfetch = local.opencode_permission
      # A headless run that hits a question auto-rejects it and stops.
      external_directory = local.opencode_permission
    }
    # The plugin brings the Massdriver skill and agents. The MCP server is defined
    # here instead, pinned and off until the VM has a Massdriver key.
    plugin = [["@massdriver/opencode", { mcp = false }]]
    mcp = {
      massdriver = {
        type    = "local"
        command = ["docker", "run", "-i", "--rm", "-e", "MASSDRIVER_API_KEY", "-e", "MASSDRIVER_ORGANIZATION_ID", "-e", "MASSDRIVER_URL", local.mcp_image]
        enabled = false
        timeout = 30000
      }
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
    for k, v in { permissions = { defaultMode = "bypassPermissions" } } : k => v if local.autonomy == "free"
  }
}
