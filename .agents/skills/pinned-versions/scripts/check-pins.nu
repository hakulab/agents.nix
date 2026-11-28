#!/usr/bin/env nu

# ==================================================================================================
# Pinned Version Drift Check
# ==================================================================================================
# Compare the registered manual pins against their upstream values and report which ones have
# drifted. Renovate manages flake inputs and GitHub Actions. See ../SKILL.md for update guidance.
#
# Run with --help for usage.
# ==================================================================================================

source versions.nu

# --------------------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------------------

# A missing prerequisite leaves the run incomplete, so it shares exit 2 with a failed query.
def die [msg: string] {
  print -e $"error: ($msg)"
  exit 2
}

def repo-root []: nothing -> string {
  try {
    ^git rev-parse --show-toplevel | str trim
  } catch {
    die "cannot find the repository root. Run inside the agents.nix checkout."
  }
}

# A failed lookup leaves no comparable value, so the caller reports UNKNOWN.
def query [pin: string, closure: closure]: nothing -> string {
  try {
    let value = (do $closure | into string | str trim)

    if ($value | is-empty) {
      error make {msg: "no value found"}
    }
    $value
  } catch {|err|
    print -e $"  ($pin): ($err.msg)"
    ""
  }
}

# --------------------------------------------------------------------------------------------------
# Upstream queries
# --------------------------------------------------------------------------------------------------

def --wrapped gh-api [path: string, jq: string, ...args: string]: nothing -> string {
  let result = (
    ^gh api $path
      --hostname github.com
      --jq $jq
      ...$args
    | complete
  )

  if $result.exit_code != 0 {
    error make {msg: ($result.stderr | str trim)}
  }
  $result.stdout | str trim
}

def gh-latest-release [repo: string]: nothing -> string {
  gh-api $"repos/($repo)/releases/latest" ".tag_name"
}

def gh-releases [repo: string]: nothing -> list<record> {
  let jq = ".[] | select(.draft == false) | @json"
  gh-api $"repos/($repo)/releases?per_page=100" $jq --paginate
  | from json --objects
}

def gh-newest-tag [repo: string]: nothing -> string {
  newest-version (gh-api $"repos/($repo)/tags" ".[].name" --paginate | lines)
}

def gh-newest-tag-head [repo: string]: nothing -> string {
  let tag = (gh-newest-tag $repo)

  if ($tag | is-empty) {
    error make {msg: "no stable version tag found"}
  }
  gh-api $"repos/($repo)/commits/($tag)" ".sha"
}

# A release without the expected binary cannot update the pin.
def gh-latest-release-with-asset [repo: string, asset: string]: nothing -> string {
  gh-releases $repo
  | where {|release| not $release.prerelease }
  | where {|release| $release.assets | any {|entry| $entry.name == $asset } }
  | first
  | get tag_name
}

# --------------------------------------------------------------------------------------------------
# Pin extraction
# --------------------------------------------------------------------------------------------------

def nix-attr [root: string, file: string, regex: string]: nothing -> string {
  open --raw ($root | path join $file) | parse --regex $regex | get v.0
}

def nix-version [root: string, file: string]: nothing -> string {
  nix-attr $root $file '(?m)^\s*version = "(?<v>[^"]+)"'
}

def nix-version-v [root: string, file: string]: nothing -> string {
  $"v(nix-version $root $file)"
}

def action-pins [root: string]: nothing -> list<string> {
  [".github/workflows" ".github/actions"]
  | each {|dir| glob ($root | path join $dir "**/*") }
  | flatten
  | where {|p|
    ($p | path type) == "file" and ($p | path parse | get extension) in ["yml" "yaml"]
  }
  | each {|p|
    let doc = (open $p)
    let jobs = ($doc | get -o jobs | default {} | values)
    [
      ($jobs | get -o uses)
      ($jobs | each {|job| $job | get -o steps | default [] | get -o uses } | flatten)
      ($doc | get -o runs.steps | default [] | get -o uses)
    ]
    | flatten
  }
  | flatten
  | compact
  | where {|pin|
    not ($pin | str starts-with "./") and not ($pin | str starts-with "docker://")
  }
  | uniq
  | sort
}

# --------------------------------------------------------------------------------------------------
# Pin registry
# --------------------------------------------------------------------------------------------------

# Renovate's github-actions manager updates these refs, so the row delegates.
def action-pin [pin: string]: nothing -> record {
  {
    pin: ($pin | split row "@" | first)
    local: {|| $pin | split row "@" | last }
    delegated: "renovate"
  }
}

# Each row pairs a pin name with closures that read the local value and the upstream value. Both
# stay lazy so list can print the registry without touching the network.
def registry [root: string]: nothing -> list<record> {
  [
    {
      title: "OMP extensions (rev + hash)"
      pins: [
        {
          pin: "omp-telegram"
          local: {||
            let file = "modules/home/omp/extensions.nix"
            nix-attr $root $file 'rev = "(?<v>[0-9a-f]{40})"'
          }
          # Upstream publishes tags without GitHub release objects.
          upstream: {|| gh-newest-tag-head "TerrifiedBug/omp-telegram" }
        }
      ]
    }
    {
      title: "Nix-built overlay packages"
      pins: [
        {
          pin: "acpx"
          local: {|| nix-version-v $root "packages/acpx/default.nix" }
          upstream: {|| gh-latest-release "openclaw/acpx" }
        }
        {
          pin: "mcp-server-github"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-github/default.nix" }
          upstream: {|| gh-latest-release "github/github-mcp-server" }
        }
        {
          pin: "mcp-server-gitlab"
          local: {|| nix-version-v $root "packages/mcp/mcp-server-gitlab/default.nix" }
          upstream: {|| gh-latest-release "zereight/gitlab-mcp" }
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
            nix-attr $root $file 'download/(?<v>[^/]+)/toasty-x64\.exe'
          }
          # cspell:ignore shanselman
          upstream: {|| gh-latest-release-with-asset "shanselman/toasty" "toasty-x64.exe" }
        }
      ]
    }
    {
      title: "GitHub Actions"
      pins: (try {
        action-pins $root | each {|pin| action-pin $pin }
      } catch {
        []
      })
    }
  ]
}

# --------------------------------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------------------------------

def resolve []: list<record> -> list<record> {
  par-each --keep-order {|row|
    if ($row.delegated? | is-not-empty) {
      let pinned = (query $row.pin $row.local)
      return {
        pin: $row.pin
        pinned: $pinned
        upstream: "renovate"
        status: $row.delegated
      }
    }

    let pinned = (query $row.pin $row.local)
    let upstream = (query $row.pin $row.upstream)
    let status = if ($pinned | is-empty) or ($upstream | is-empty) {
      "UNKNOWN"
    } else if $pinned == $upstream {
      "ok"
    } else {
      "STALE"
    }

    {
      pin: $row.pin
      pinned: ($pinned | default --empty "?")
      upstream: ($upstream | default --empty "?")
      status: $status
    }
  }
}

def resolve-group [group: record]: nothing -> record {
  let rows = if ($group.pins | is-empty) {
    # An empty group would print as a clean sweep, indistinguishable from every pin being current.
    print -e $"  ($group.title): no pins matched"
    [
      {
        pin: $group.title
        pinned: "?"
        upstream: "?"
        status: "UNKNOWN"
      }
    ]
  } else {
    $group.pins | resolve
  }
  {
    title: $group.title
    rows: $rows
  }
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

# Compare registered manual pins with upstream versions.
def "main check" [] {
  if (which gh | is-empty) {
    die "gh not found. Install GitHub CLI and authenticate to github.com."
  }
  if (^gh auth status --hostname github.com | complete).exit_code != 0 {
    die "GitHub authentication check failed. Check credentials and network access."
  }

  # Resolution finishes before anything prints, since par-each threads would otherwise interleave
  # their sections.
  let groups = (
    registry (repo-root)
    | par-each --keep-order {|group| resolve-group $group }
  )

  for group in $groups {
    print $"\n($group.title)"
    print ($group.rows | table)
  }
  let rows = ($groups | get rows | flatten)
  let stale = ($rows | where status == "STALE" | length)
  let unknown = ($rows | where status == "UNKNOWN" | length)

  print $"\n($stale) stale, ($unknown) unknown."
  if $unknown > 0 {
    print "UNKNOWN means a lookup failed. Rerun, and fix the printed cause if it persists."
    exit 2
  }
  if $stale > 0 {
    exit 1
  }
}

# List the registered pins without querying upstream.
def "main list" [] {
  print "Manual pins tracked by this script:"
  for group in (registry (repo-root)) {
    print $"\n($group.title)"
    for pin in $group.pins {
      print $"  ($pin.pin)"
    }
  }
  print "\nRenovate owns the flake.lock inputs and the GitHub Actions refs."
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
