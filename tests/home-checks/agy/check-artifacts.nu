# ==================================================================================================
# Antigravity CLI Rendered Artifact Assertions
# ==================================================================================================

use std/assert

# Compare the wrapper arguments separately from the JSON settings.
def take-settings [result: record, offset: int]: nothing -> record {
  let args = $result.stdout | split row "\n"
  assert equal ($args | get $offset) "--settings"
  {
    settings: ($args | get ($offset + 1) | from json)
    args: ($args | reject ($offset + 1) $offset)
  }
}

# Verify the generated ACP registrations, auth wrappers, and permissions.
def main [] {
  hide-env --ignore-errors HTTPS_PROXY NO_PROXY GEMINI_API_KEY GOOGLE_GEMINI_BASE_URL AGY_ADC_AUTH
  let artifacts = $env.ARTIFACTS | from json

  # ------------------------------------------------------------------------------------------------
  # ACP registrations
  # ------------------------------------------------------------------------------------------------
  for path in [$artifacts.managedAcp $artifacts.fallbackAcp] {
    assert equal (open $path).agents.agy.argv [$artifacts.profileAgy "acp" "--sandbox"]
  }
  assert equal (open $artifacts.explicitAcp).agents.agy.argv [
    $artifacts.explicitExecutable
    "acp"
    "--sandbox"
  ]
  assert ("agy" not-in (open $artifacts.optOutAcp).agents)

  # ------------------------------------------------------------------------------------------------
  # Fallback wrapper
  # ------------------------------------------------------------------------------------------------
  let fallback = ^$artifacts.fallbackWrapper acp | complete
  assert equal $fallback.exit_code 0 $fallback.stderr
  assert equal ($fallback.stdout | split row "\n" | skip 5) [
    "--model"
    "gemini-4-neon-low"
    "acp"
    ""
  ]

  # ------------------------------------------------------------------------------------------------
  # Official profile wrapper and permissions
  # ------------------------------------------------------------------------------------------------
  $env.GEMINI_API_KEY = "stale"
  $env.GOOGLE_GEMINI_BASE_URL = "https://stale.example.test"
  $env.AGY_ADC_AUTH = "stale"
  $env.HOME = (mktemp --directory)
  let settings_dir = $env.HOME | path join ".gemini" "antigravity-cli"
  mkdir $settings_dir
  let native_settings = $settings_dir | path join "settings.json"

  let saved = {
    permissions: {
      allow: ["command(example status)"]
      ask: ["command(custom-check)"]
      deny: ["read_file(/fixtures/private)"]
    }
  }
  $saved | to json | save $native_settings

  let official = ^$artifacts.managedWrapper --model gemini-pro-orchestrator-neon | complete
  assert equal $official.exit_code 0 $official.stderr

  let official_launch = take-settings $official 5
  let settings = $official_launch.settings
  assert equal $settings.modelProvider ""
  assert equal $settings.customSetting "enabled"
  assert equal $settings.agentMode "auto"
  assert equal $settings.enableTerminalSandbox true
  assert equal $settings.toolPermission "proceed-in-sandbox"
  assert ("command(gh pr view)" in $settings.permissions.allow)
  assert ("command(gh)" not-in $settings.permissions.allow)
  assert ("command(cat)" not-in $settings.permissions.allow)
  assert ("command(example status)" in $settings.permissions.allow)
  assert ("command(gh pr merge)" in $settings.permissions.ask)
  assert ("command(sops)" in $settings.permissions.ask)
  assert ("command(example deploy)" in $settings.permissions.ask)
  assert ("command(custom-check)" in $settings.permissions.ask)
  assert ("read_file(/fixtures/private)" in $settings.permissions.deny)
  assert ("mcp(Local/read_item)" in $settings.permissions.allow)
  assert ("mcp(Local/write_item)" in $settings.permissions.ask)
  assert ("mcp(Hidden/read_item)" not-in $settings.permissions.allow)
  assert ($"read_file\(($artifacts.fixtureKey)\)" in $settings.permissions.deny)
  assert ($"read_file\(($artifacts.instructionsPath)\)" in $settings.permissions.allow)
  assert ($"write_file\(($artifacts.instructionsPath)\)" in $settings.permissions.deny)
  assert equal $official_launch.args [
    "https://proxy.example.test"
    "localhost,127.0.0.1,10.0.0.0/8,direct.example.test"
    ""
    ""
    ""
    "--model"
    "gemini-4-hydrogen-medium"
    "--model"
    "gemini-pro-orchestrator-neon"
    ""
  ]

  # ------------------------------------------------------------------------------------------------
  # API-key profile wrapper
  # ------------------------------------------------------------------------------------------------
  let api = ^$artifacts.apiWrapper models | complete
  assert equal $api.exit_code 0 $api.stderr

  let api_launch = take-settings $api 5
  assert equal $api_launch.settings.modelProvider "gemini"
  assert equal $api_launch.settings.permissions $settings.permissions
  assert equal $api_launch.args [
    ""
    ""
    "fixture-key"
    "https://gemini.example.test"
    ""
    "--model"
    "gemini-4-neon-medium"
    "models"
    ""
  ]
  assert equal (open $native_settings) $saved

  # ------------------------------------------------------------------------------------------------
  # Missing API key
  # ------------------------------------------------------------------------------------------------
  let missing = ^$artifacts.missingKeyWrapper models | complete
  assert equal $missing.exit_code 1
  assert ($missing.stderr | str contains "could not read the API key for profile ai-studio")
  assert equal $missing.stdout ""
}
