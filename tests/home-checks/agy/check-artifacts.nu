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

# Verify the generated ACP registrations and launcher arguments.
def main [] {
  let artifacts = $env.ARTIFACTS | from json
  for path in $artifacts.profileConfigs {
    let config = open $path
    assert equal $config.agents.agy.argv [$artifacts.profileAgy "acp" "--sandbox"]
  }

  let explicit = open $artifacts.explicit
  assert equal $explicit.agents.agy.argv [$artifacts.explicitExecutable "acp" "--sandbox"]

  let opt_out = open $artifacts.optOut
  assert ("agy" not-in $opt_out.agents)

  let combined = $artifacts.combinedWrapper
  let combined_result = ^$combined --model gemini-pro-orchestrator-neon | complete
  assert equal $combined_result.exit_code 0 $combined_result.stderr
  let combined_launch = take-settings $combined_result 2
  assert equal $combined_launch.settings.modelProvider ""
  assert equal $combined_launch.args [
    "https://proxy.example.test"
    "localhost,127.0.0.1,10.0.0.0/8,direct.example.test"
    "--model"
    "gemini-4-hydrogen-medium"
    "--model"
    "gemini-pro-orchestrator-neon"
    ""
  ]

  hide-env --ignore-errors HTTPS_PROXY NO_PROXY
  let fallback = $artifacts.fallbackWrapper
  let fallback_result = ^$fallback acp | complete
  assert equal $fallback_result.exit_code 0 $fallback_result.stderr
  assert equal ($fallback_result.stdout | split row "\n") [
    ""
    ""
    "--model"
    "gemini-4-neon-low"
    "acp"
    ""
  ]

  $env.GEMINI_API_KEY = "stale"
  $env.GOOGLE_GEMINI_BASE_URL = "https://stale.example.test"
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

  let official = $artifacts.officialAuth
  let result = ^$official models | complete
  assert equal $result.exit_code 0 $result.stderr
  let official_launch = take-settings $result 2
  let settings = $official_launch.settings
  assert equal $settings.modelProvider ""
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
  assert ("mcp(Sample Tools/read_item)" in $settings.permissions.allow)
  assert ("mcp(Sample Tools/write_item)" in $settings.permissions.ask)
  assert ("mcp(Unused Tools/read_item)" not-in $settings.permissions.allow)
  assert ($"read_file\(($artifacts.fixtureKey)\)" in $settings.permissions.deny)
  assert ($"read_file\(($artifacts.instructionsPath)\)" in $settings.permissions.allow)
  assert ($"write_file\(($artifacts.instructionsPath)\)" in $settings.permissions.deny)
  assert equal $official_launch.args [
    ""
    ""
    "--model"
    "gemini-4-neon-low"
    "models"
    ""
  ]

  let api = $artifacts.apiAuth
  let result = ^$api models | complete
  assert equal $result.exit_code 0 $result.stderr
  let api_launch = take-settings $result 3
  assert equal $api_launch.settings.modelProvider "gemini"
  assert equal $api_launch.settings.permissions $settings.permissions
  assert equal $api_launch.args [
    "key-loaded"
    "key-present"
    "https://gemini.example.test"
    "--model"
    "gemini-4-hydrogen-low"
    "models"
    ""
  ]
  assert equal (open $native_settings) $saved

  let result = ^$api acp | complete
  assert equal $result.exit_code 1
  assert ($result.stderr | str contains "ACP requires the official profile")
  assert equal $result.stdout ""

  let result = ^$api --model gemini-4-neon-low acp | complete
  assert equal $result.exit_code 1
  assert ($result.stderr | str contains "ACP requires the official profile")

  let result = ^$api -p acp | complete
  assert equal $result.exit_code 0 $result.stderr

  let result = ^$api --settings '{"notifications":true}' models | complete
  assert equal $result.exit_code 1
  assert ($result.stderr | str contains "the API-key profile manages --settings")

  let missing = $artifacts.missingKey
  let result = ^$missing models | complete
  assert equal $result.exit_code 1
  assert ($result.stderr | str contains "could not read the API key for profile ai-studio")
  assert equal $result.stdout ""
}
