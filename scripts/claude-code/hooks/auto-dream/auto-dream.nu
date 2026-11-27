#!/usr/bin/env nu

# ==================================================================================================
# Auto-Dream
# ==================================================================================================
# Claude Code's native auto-dream needs a server-side flag that disabling nonessential traffic never
# fetches. This hook applies the same gates and asks the session to dream in a background agent.
# ==================================================================================================

const MIN_AGE = 24hr
const MIN_SESSIONS = 5
# A nudge the session ignored, or a dream it abandoned, comes back after this long.
const RETRY_AFTER = 1hr

const PROJECTS_DIR = $nu.home-dir | path join ".claude/projects"
const NUDGE_DIR = $nu.cache-dir | path join "claude-code/auto-dream"

# Claude Code's project directory name for a path.
def project-slug [path: string]: nothing -> string {
  $path | str replace --all --regex "[^a-zA-Z0-9]" "-"
}

# Git lists the main worktree first. All linked worktrees share its memory store.
def worktree-paths [git: string, cwd: string]: nothing -> list<string> {
  let result = (^$git -C $cwd worktree list --porcelain -z | complete)
  if $result.exit_code != 0 {
    return []
  }

  $result.stdout
  | split row (char nul)
  | where {|field| $field | str starts-with "worktree " }
  | each {|field| $field | str substring 9.. }
}

def modified [path: string]: nothing -> datetime {
  if ($path | path exists) {
    ls $path | get 0.modified
  } else {
    0 | into datetime
  }
}

def memories [store: string]: nothing -> list<string> {
  if not ($store | path exists) {
    return []
  }

  ls $store
  | where type == "file" and ($it.name | str ends-with ".md")
  | get name
  | where ($it | path basename) != "MEMORY.md"
}

# The first recorded working directory identifies where the session started.
def transcript-cwd [path: string]: nothing -> string {
  open --raw $path
  | lines
  | each {|line| try { ($line | from json).cwd? } }
  | where {|cwd| ($cwd | describe) == "string" and ($cwd | str starts-with "/") }
  | first
  | default ""
}

def checkout-contains [root: list<string>, parts: list<string>]: nothing -> bool {
  let depth = ($root | length)
  if ($parts | first $depth) != $root {
    return false
  }

  $parts
  | skip $depth
  | enumerate
  | all {|entry|
    let directory = ($parts | first ($depth + $entry.index + 1) | path join)
    not ($directory | path join ".git" | path exists)
  }
}

def sessions-since [worktrees: list<string>, since: datetime, current: string]: nothing -> int {
  let slugs = ($worktrees | each {|root| project-slug $root })
  let roots = ($worktrees | each {|root| $root | path expand | path split })

  # Slugs narrow the search. Distinct project paths can share a slug or its prefix.
  ls $PROJECTS_DIR
  | where type == "dir"
  | where {|dir|
    let name = ($dir.name | path basename)
    $slugs | any {|slug| $name | str starts-with $slug }
  }
  | each {|dir| ls $dir.name }
  | flatten
  | where type == "file" and ($it.name | str ends-with ".jsonl") and $it.modified > $since
  | where ($it.name | path parse | get stem) != $current
  | where {|entry|
    let cwd = (try { transcript-cwd $entry.name } catch { "" })
    if ($cwd | is-empty) {
      return false
    }

    let parts = ($cwd | path expand | path split)
    $roots | any {|root| checkout-contains $root $parts }
  }
  | length
}

def nudge [config: record, input: record]: nothing -> any {
  let worktrees = (worktree-paths $config.git $input.cwd)
  if ($worktrees | is-empty) {
    return null
  }

  let slug = (project-slug ($worktrees | first))
  let store = ($PROJECTS_DIR | path join $slug "memory")
  if (memories $store | is-empty) {
    return null
  }

  let since = (modified ($store | path join ".consolidate-lock"))
  let marker = ($NUDGE_DIR | path join $slug)
  if (date now) - $since < $MIN_AGE or (date now) - (modified $marker) < $RETRY_AFTER {
    return null
  }

  let sessions = (sessions-since $worktrees $since $input.session_id)
  if $sessions < $MIN_SESSIONS {
    return null
  }

  mkdir $NUDGE_DIR
  touch $marker
  let last = if $since == (0 | into datetime) {
    "none recorded"
  } else {
    $since | format date "%Y-%m-%d"
  }
  let context = (
    $config.prompt
    | str replace --all "@model@" $config.model
    | str replace --all "@sessions@" ($sessions | into string)
    | str replace --all "@since@" $last
    | str replace --all "@store@" $store
  )

  # SessionStart gives the model `additionalContext`, while `systemMessage` reaches only the user.
  {
    systemMessage: $"Memory consolidation is due after ($sessions) sessions, so Claude will dream in a background agent."
    hookSpecificOutput: {
      hookEventName: "SessionStart"
      additionalContext: $context
    }
  }
  | to json --raw
}

def main [
  --config: path # Wrapper-supplied JSON with git, the model, and the prompt
] {
  let out = try {
    nudge (open $config) (^cat | from json)
  } catch {
    null
  }
  if $out != null {
    print $out
  }
}
