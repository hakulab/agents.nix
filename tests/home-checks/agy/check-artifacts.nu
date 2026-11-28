# ==================================================================================================
# Antigravity CLI Rendered Artifact Assertions
# ==================================================================================================

use std/assert

# Verify the generated ACP registrations and launcher arguments.
def main [] {
  let artifacts = $env.ARTIFACTS | from json
  for path in $artifacts.profileConfigs {
    let config = open $path
    assert equal $config.agents.agy.argv [$artifacts.profileAgy "acp"]
  }

  let explicit = open $artifacts.explicit
  assert equal $explicit.agents.agy.argv [$artifacts.explicitExecutable "acp"]

  let opt_out = open $artifacts.optOut
  assert ("agy" not-in $opt_out.agents)

  let combined = $artifacts.combinedWrapper
  let combined_result = ^$combined --model gemini-pro-orchestrator-neon | complete
  assert equal $combined_result.exit_code 0 $combined_result.stderr
  assert equal ($combined_result.stdout | split row "\n") [
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
}
