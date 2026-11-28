#!/usr/bin/env nu

# ==================================================================================================
# Pinned Version Drift Check
# ==================================================================================================
# Compare the registered manual pins against their upstream values. See ../SKILL.md for update
# guidance.
# ==================================================================================================

use pin-check

# --------------------------------------------------------------------------------------------------
# Pin registry
# --------------------------------------------------------------------------------------------------

def nix-version-v [root: string, file: string]: nothing -> string {
  $"v(pin-check nix-version $root $file)"
}

# A release without the expected binary cannot update the pin.
def gh-latest-release-with-asset [repo: string, asset: string]: nothing -> string {
  pin-check gh-releases $repo
  | where {|release| not $release.prerelease }
  | where {|release| $release.assets | any {|entry| $entry.name == $asset } }
  | first
  | get tag_name
}

def registry []: nothing -> list<record> {
  let root = (pin-check repo-root "agents.nix")
  [
    {
      title: "OMP extensions (rev + hash)"
      pins: [
        {
          pin: "omp-telegram"
          local: {||
            let file = "modules/home/omp/extensions.nix"
            pin-check nix-attr $root $file 'rev = "(?<v>[0-9a-f]{40})"'
          }
          # Upstream publishes tags without GitHub release objects.
          upstream: {|| pin-check gh-newest-tag-head "TerrifiedBug/omp-telegram" }
        }
      ]
    }
    {
      title: "Nix-built overlay packages"
      pins: [
        {
          pin: "acpx"
          local: {|| nix-version-v $root "packages/acpx/default.nix" }
          upstream: {|| pin-check gh-latest-release "openclaw/acpx" }
        }
        {
          pin: "mcp-server-github"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-github/default.nix" }
          upstream: {|| pin-check gh-latest-release "github/github-mcp-server" }
        }
        {
          pin: "mcp-server-gitlab"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-gitlab/default.nix" }
          upstream: {|| pin-check gh-latest-release "zereight/gitlab-mcp" }
        }
      ]
    }
    {
      title: "Windows notification helper"
      pins: [
        {
          pin: "toasty"
          local: {||
            let file = "modules/home/shared/notify.nix"
            pin-check nix-attr $root $file 'download/(?<v>[^/]+)/toasty-x64\.exe'
          }
          # cspell:ignore shanselman
          upstream: {|| gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe" }
        }
      ]
    }
    {
      title: "GitHub Actions"
      pins: (try {
        pin-check action-pins $root | each {|pin| pin-check action-pin $pin }
      } catch {
        []
      })
    }
  ]
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Compare registered manual pins with upstream versions.
def "main check" [] {
  pin-check check {|| registry }
}

# List the registered pins without querying upstream.
def "main list" [] {
  let footer = "Renovate owns the flake.lock inputs and the GitHub Actions refs."
  pin-check list {|| registry } --footer $footer
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
