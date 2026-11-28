#!/usr/bin/env nu

# ==================================================================================================
# Pinned Versions
# ==================================================================================================

const REPO_ROOT = path self "../../../.."

# --------------------------------------------------------------------------------------------------
# Pin readers
# --------------------------------------------------------------------------------------------------

def source-value [file: string, pattern: string]: nothing -> string {
  open --raw ($REPO_ROOT | path join $file)
  | parse --regex $pattern
  | get value.0
}

def package-version [file: string]: nothing -> string {
  $"v(source-value $file '(?m)^\s*version = "(?<value>[^"]+)"')"
}

# --------------------------------------------------------------------------------------------------
# Upstream releases and tags
# --------------------------------------------------------------------------------------------------

def --wrapped github [endpoint: string, filter: string, ...options: string]: nothing -> string {
  let result = (
    ^gh api $endpoint
      --hostname github.com
      --jq $filter
      ...$options
    | complete
  )

  if $result.exit_code != 0 {
    error make { msg: ($result.stderr | str trim) }
  }

  $result.stdout | str trim
}

def latest-release [repo: string]: nothing -> string {
  github $"repos/($repo)/releases/latest" ".tag_name"
}

def latest-telegram-rev []: nothing -> string {
  let repo = "TerrifiedBug/omp-telegram"
  let tag = (
    github $"repos/($repo)/tags?per_page=100" ".[].name" --paginate
    | lines
    | where {|tag| $tag =~ '^v?[0-9]+\.[0-9]+\.[0-9]+$' }
    | sort-by --natural {|tag| $tag | str replace -r "^v" "" }
    | last
  )

  github $"repos/($repo)/commits/($tag)" ".sha"
}

def latest-toasty-release []: nothing -> string {
  let filter = '.[] | select(.draft == false and .prerelease == false and any(.assets[]; .name == "toasty-x64.exe")) | .tag_name'
  # cspell:ignore shanselman
  github "repos/shanselman/toasty/releases?per_page=100" $filter --paginate
  | lines
  | first
}

# --------------------------------------------------------------------------------------------------
# Pin inventory
# --------------------------------------------------------------------------------------------------

def pins []: nothing -> table {
  [
    {
      pin: "acpx"
      pinned: {|| package-version "packages/acpx/default.nix" }
      upstream: {|| latest-release "openclaw/acpx" }
    }
    {
      pin: "mcp-server-github"
      pinned: {|| package-version "packages/mcp/mcp-server-github/default.nix" }
      upstream: {|| latest-release "github/github-mcp-server" }
    }
    {
      pin: "mcp-server-gitlab"
      pinned: {|| package-version "packages/mcp/mcp-server-gitlab/default.nix" }
      upstream: {|| latest-release "zereight/gitlab-mcp" }
    }
    {
      pin: "omp-telegram"
      pinned: {|| source-value "modules/home/omp/extensions.nix" 'rev = "(?<value>[0-9a-f]{40})"' }
      upstream: {|| latest-telegram-rev }
    }
    {
      pin: "toasty"
      pinned: {||
        source-value "modules/home/shared/notify.nix" 'download/(?<value>[^/]+)/toasty-x64\.exe'
      }
      upstream: {|| latest-toasty-release }
    }
  ]
}

# --------------------------------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------------------------------

def query [pin: string, field: string, lookup: closure]: nothing -> string {
  try {
    let value = (do $lookup)
    if ($value | is-empty) {
      error make { msg: "no value found" }
    }
    $value
  } catch {|err|
    print -e $"($pin) [($field)]: ($err.msg)"
    ""
  }
}

# Compare registered manual pins with upstream versions.
def "main check" [] {
  let rows = (
    pins
    | each {|entry|
      let pinned = (query $entry.pin "pinned" $entry.pinned)
      let upstream = (query $entry.pin "upstream" $entry.upstream)
      let status = if ($pinned | is-empty) or ($upstream | is-empty) {
        "UNKNOWN"
      } else if $pinned == $upstream {
        "ok"
      } else {
        "STALE"
      }

      {
        pin: $entry.pin
        pinned: ($pinned | default --empty "?")
        upstream: ($upstream | default --empty "?")
        status: $status
      }
    }
  )

  print ($rows | table)
  let stale = ($rows | where status == "STALE" | length)
  let unknown = ($rows | where status == "UNKNOWN" | length)
  print $"\n($stale) stale, ($unknown) unknown."

  if $unknown > 0 {
    exit 2
  }
  if $stale > 0 {
    exit 1
  }
}

# List the registered pins without querying upstream.
def "main list" [] {
  print "Manual pins tracked by this script:"
  for pin in (pins | get pin) {
    print $"  ($pin)"
  }
}

# Check registered manual pins for upstream drift by default.
def main [] {
  main check
}
