# ==================================================================================================
# Claude Code Rendered Artifact Assertions
# ==================================================================================================

use std/assert

# --------------------------------------------------------------------------------------------------
# Settings and hooks
# --------------------------------------------------------------------------------------------------

def check-settings [settings: record, minimal: record, home_directory: string] {
  assert equal $settings."$schema" "https://json.schemastore.org/claude-code-settings.json"
  assert equal $settings.permissions.defaultMode "auto"
  assert equal $settings.permissions.deny ["Agent(Explore)"]

  let trusted_script = $"Bash\(($home_directory)/.claude/skills/trusted-skill/scripts/check.sh *\)"
  assert ($trusted_script in $settings.permissions.allow)
  assert ("mcp__CustomHttp__list_items" in $settings.permissions.allow)
  assert ("mcp__CustomHttp__edit_item" not-in $settings.permissions.allow)
  assert (
    $settings.autoMode.environment | any {|entry| $entry | str contains "github.com/example-org" }
  )
  assert ("Custom allow policy for tests." in $settings.autoMode.allow)

  let plugins = $settings.enabledPlugins
  assert equal $plugins."skill-creator@claude-plugins-official" true
  assert equal $plugins."rust-analyzer-lsp@claude-plugins-official" true
  assert equal $plugins."custom-plugin@custom-mkt" true
  assert ("workmux-status@workmux" not-in $plugins)

  let marketplaces = $settings.extraKnownMarketplaces
  let official_marketplace = $marketplaces.claude-plugins-official.source.repo
  assert equal $official_marketplace "anthropics/claude-plugins-official"
  assert equal $marketplaces.custom-mkt.source.repo "example/custom-mkt"
  assert ("workmux" not-in $marketplaces)

  assert equal $settings.statusLine.command "claude-statusline"
  assert equal $settings.theme "light"
  assert equal $settings.env.CUSTOM_CLAUDE_ENV "yes"
  assert ($settings.processWrapper | str ends-with "claude-process-wrapper")

  assert ("statusLine" not-in $minimal)
  assert equal $minimal.hooks {}
}

def check-hooks [hooks: record] {
  assert (
    $hooks.Stop
    | each {|group| $group.hooks }
    | flatten
    | any {|hook|
      $hook.type? == "command" and ($hook.command | str contains "--app claude --claude-stop")
    }
  )

  assert (
    $hooks.PermissionRequest
    | any {|request|
      $request.matcher? == "AskUserQuestion" and (
        $request.hooks
        | any {|hook|
          (
            ($hook.command | str contains "--app claude --stdin")
            and not ($hook.command | str contains "--claude-stop")
          )
        }
      )
    }
  )

  assert length $hooks.PostToolUse 2
  assert length $hooks.SessionStart 1
  assert length $hooks.TeammateIdle 1
  assert length $hooks.WorktreeCreate 1
  assert length $hooks.WorktreeRemove 1
}

# --------------------------------------------------------------------------------------------------
# Wrapper and MCP
# --------------------------------------------------------------------------------------------------

def referenced-path [text: string, filename: string]: nothing -> string {
  let suffix = $filename | str replace --all "." '\.'
  $text
  | parse --regex ('(?<path>/nix/store/[^\x22\x27\s]+' + $suffix + ')')
  | get 0.path
}

def check-wrapper [wrapper: string] {
  assert ($wrapper | str contains "CLAUDE_CODE_CERT_STORE")
  assert ($wrapper | str contains "CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL")
  assert ($wrapper | str contains "profile-loader.sh")
  assert ($wrapper | str contains "session-args.sh")

  let session_args = open --raw (referenced-path $wrapper "session-args.sh")
  let mcp = open (referenced-path $session_args "claude-code-mcp-config.json")
  assert ("GitHub" in $mcp.mcpServers)
  assert equal $mcp.mcpServers.CustomHttp.url "https://mcp.example.test/mcp"
  assert ("DeepWiki" not-in $mcp.mcpServers)
}

# --------------------------------------------------------------------------------------------------
# Profile bundles
# --------------------------------------------------------------------------------------------------

def check-profiles [profiles: record] {
  let gateway_env = open --raw ($profiles.gateway | path join "env.sh")
  assert ($gateway_env | str contains "ANTHROPIC_AUTH_TOKEN")
  assert ($gateway_env | str contains "CUSTOM_PROVIDER_FLAG")
  assert ($gateway_env | str contains "EXTRA_PROVIDER_SECRET")
  assert ($gateway_env | str contains "NODE_EXTRA_CA_CERTS")
  assert ($gateway_env | str contains "OVERRIDE_FLAG")
  assert ($gateway_env | str contains "x-tenant: demo")
  assert ($gateway_env | str contains "x-override: 1")
  assert (not ($gateway_env | str contains "CLAUDE_CODE_AUTO_MODE_SERVER"))

  let alternate_env = open --raw ($profiles.alternate | path join "env.sh")
  assert ($alternate_env | str contains "CLAUDE_CODE_AUTO_MODE_SERVER")
  assert ($alternate_env | str contains "alt/claude-haiku-5-5")

  let oauth_env = open --raw ($profiles.oauth | path join "env.sh")
  assert ($oauth_env | str contains "CLAUDE_CODE_OAUTH_TOKEN")

  let architect = $profiles.gateway | path join "agents/architect.md"
  let reviewer = $profiles.gateway | path join "agents/reviewer.md"
  let implementer = $profiles.gateway | path join "agents/implementer.md"
  ^test -f $architect
  ^test -f $reviewer
  ^test ! -e $implementer
  assert ("name: reviewer" in (open --raw $reviewer | lines))

  let gateway = open (referenced-path $gateway_env "claude-code-settings-gw-claude.json")
  assert equal $gateway.effortLevel "high"
  assert equal $gateway.modelSettings.claude-opus-5-5.effortLevel "max"
  assert equal $gateway.modelSettings.claude-opus-5-5.autoCompactWindow 250000
  assert equal $gateway.modelSettings.claude-sonnet-5-5.autoCompactWindow 400000
  assert equal $gateway.modelOverrides.claude-opus-5-5 "gw/claude-opus-5-5"
  assert equal $gateway.modelOverrides.claude-haiku-5-5 "custom/claude-haiku-5-5"

  let custom_env = open --raw ($profiles.custom | path join "env.sh")
  let custom = open (referenced-path $custom_env "claude-code-settings-custom.json")
  assert equal $custom.effortLevel "low"
  assert equal $custom.permissions.deny ["WebSearch"]
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Verify the generated settings, wrapper, MCP configuration, and profile bundles.
def main [] {
  let artifacts = $env.ARTIFACTS | from json
  let settings = open $artifacts.settings
  check-settings $settings (open $artifacts.minimalSettings) $env.HOME_DIRECTORY
  check-hooks $settings.hooks
  check-wrapper (open --raw $artifacts.wrapper)
  check-profiles $artifacts.profiles
}
