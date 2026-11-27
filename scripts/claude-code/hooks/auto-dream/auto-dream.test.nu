#!/usr/bin/env nu

# ==================================================================================================
# Auto-Dream Hook Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "auto-dream.nu")

def add-session [projects: string, directory: string, id: string, cwd: string]: nothing -> string {
  let slug = ($directory | str replace --all --regex "[^a-zA-Z0-9]" "-")
  let project = ($projects | path join $slug)
  let transcript = ($project | path join $"($id).jsonl")

  mkdir $project
  [
    ({type: "file-history-snapshot"} | to json --raw)
    ({type: "user", cwd: $cwd} | to json --raw)
  ] | str join (char nl) | save $transcript

  $transcript
}

def "test auto-dream counts recent sessions from this repository and its worktrees" [] {
  let root = (mktemp --directory | path expand)
  let main = ($root | path join "app")
  let nested = ($main | path join "vendor/lib")
  let subdir = ($main | path join "examples")
  let worktree = ($root | path join "linked checkout")
  let worktree_subdir = ($worktree | path join "docs")
  let sibling = ($root | path join "app-examples")
  let other = ($root | path join "application")

  mkdir $main $nested $subdir $sibling $other
  ^git -C $main init --quiet --initial-branch main
  ^git -C $nested init --quiet --initial-branch main
  ^git -C $main -c user.name=Test -c user.email=test@example.com commit --quiet --allow-empty -m root
  ^git -C $main worktree add --quiet -b linked $worktree
  mkdir $worktree_subdir

  let projects = ($root | path join ".claude/projects")
  let cache = ($root | path join "cache")
  let slug = ($main | str replace --all --regex "[^a-zA-Z0-9]" "-")
  let memory = ($projects | path join $slug "memory")
  let cutoff = (date now) - 2day
  mkdir $memory
  touch ($memory | path join "previous.md")
  touch --timestamp $cutoff ($memory | path join ".consolidate-lock")

  add-session $projects $main "main" $main | ignore
  add-session $projects $subdir "subdir" $subdir | ignore
  add-session $projects $worktree "worktree" $worktree | ignore
  add-session $projects $worktree_subdir "linked-subdir" $worktree_subdir | ignore
  add-session $projects $main "current" $main | ignore
  let old = (add-session $projects $main "old" $main)
  touch --timestamp ($cutoff - 1day) $old

  add-session $projects $sibling "sibling" $sibling | ignore
  add-session $projects $other "other" $other | ignore
  add-session $projects $nested "nested" $nested | ignore
  '{"type":"summary"}' | save ($projects | path join $slug "missing-cwd.jsonl")

  let config = ($root | path join "config.json")
  {
    git: (which git | get 0.path)
    prompt: "Sessions: @sessions@"
    model: "test-model"
  } | to json | save $config

  let input = ({cwd: $worktree, session_id: "current"} | to json)
  with-env {HOME: $root, XDG_CACHE_HOME: $cache} {
    let before = ($input | run-script $SCRIPT --config $config)
    assert equal $before.exit_code 0 $before.stderr
    assert equal $before.stdout ""

    add-session $projects $main "qualifying" $main | ignore
    let after = ($input | run-script $SCRIPT --config $config)
    assert equal $after.exit_code 0 $after.stderr
    assert equal ($after.stdout | from json | get hookSpecificOutput) {
      hookEventName: "SessionStart"
      additionalContext: "Sessions: 5"
    }
  }
}
