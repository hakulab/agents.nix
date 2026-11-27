#!/usr/bin/env nu

# ==================================================================================================
# Worktree Create Hook Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "worktree-create.nu")
const SESSION_ID = "test-session"

# Creates a repository at `root/app`, optionally with a remote whose default branch is set.
def setup-repo [root: string, --with-origin]: nothing -> record {
  let app = ($root | path join "app")
  mkdir $app
  ^git -C $app init --quiet --initial-branch main
  ^git -C $app config user.email "test@example.com"
  ^git -C $app config user.name "Test"
  "base" | save ($app | path join "f.txt")
  ^git -C $app add --all
  ^git -C $app commit --quiet --message "base"
  if $with_origin {
    let remote = ($root | path join "remote")
    mkdir $remote
    ^git -C $remote init --quiet --bare --initial-branch main
    ^git -C $app remote add origin $remote
    ^git -C $app push origin main --quiet --set-upstream
    ^git -C $app remote set-head origin main
  }
  {
    root: $root
    app: $app
  }
}

def git-rev [repo: string, ref: string]: nothing -> string {
  ^git -C $repo rev-parse $ref | str trim
}

def invoke [payload: record, vars: record]: nothing -> record {
  let dir = (mktemp --directory)
  let log = ($dir | path join "calls.jsonl")
  let run = with-env (
    {
      PATH: ($env.PATH | prepend $env.NU_TEST_STUBS | str join ":")
      STUB_LOG: $log
    }
    | merge $vars
  ) {
    $payload
    | to json
    | run-script $SCRIPT
  }

  let calls = if ($log | path exists) {
    open $log | from json --objects
  } else {
    []
  }
  {
    run: $run
    calls: $calls
  }
}

def "test create claims a newly provisioned worktree" [] {
  let repo = (setup-repo (mktemp --directory) --with-origin)
  let remote_less = (setup-repo (mktemp --directory))
  let fallback = (git-rev $remote_less.app "HEAD")
  let cases = [
    {
      label: "origin/HEAD"
      cwd: $repo.app
      name: "demo"
      base: "origin/main"
      existing: ""
    }
    {
      label: "no origin/HEAD"
      cwd: $remote_less.app
      name: "demo"
      base: $fallback
      existing: ""
    }
    {
      label: "path lookup matched a branch with a different handle"
      cwd: $repo.app
      name: "other"
      base: "origin/main"
      existing: ($repo.root | path join "app__worktrees/another")
    }
  ]

  for case in $cases {
    let created = ($case.cwd | path dirname | path join "app__worktrees" $case.name)
    let branch = $"worktree-($case.name)"
    let result = (
      invoke {
        name: $case.name
        cwd: $case.cwd
        session_id: $SESSION_ID
      } {
        STUB_EXISTING_PATH: $case.existing
        STUB_ADD_PATH: $created
      }
    )

    assert equal $result.run.exit_code 0 $case.label
    assert equal $result.run.stdout $"($created)\n" $case.label
    assert equal ($result.calls | get args) [
      ["path" $case.name]
      ["add" $branch "--base" $case.base "--name" $case.name "--no-hooks" "--headless" "--json"]
    ] $case.label
    let git_dir = (^git -C $created rev-parse --absolute-git-dir | str trim)
    let marker = ($git_dir | path join "claude-code-worktree.json")
    assert equal (open $marker) {session_id: $SESSION_ID, branch: $branch} $case.label
    assert equal (git-rev $created "HEAD") (git-rev $case.cwd $case.base) $case.label
  }
}

def "test create refuses existing handles and branches" [] {
  let repo = (setup-repo (mktemp --directory))
  let existing = ($repo.root | path join "app__worktrees/demo")
  let payload = {
    name: "demo"
    cwd: $repo.app
    session_id: $SESSION_ID
  }

  ^git -C $repo.app worktree add --quiet -b manual $existing
  let handle_collision = (invoke $payload {STUB_EXISTING_PATH: $existing})
  assert equal $handle_collision.run.exit_code 1
  assert equal $handle_collision.run.stdout ""
  assert ($handle_collision.run.stderr | str contains "Worktree demo already exists")
  assert equal ($handle_collision.calls | get args) [["path" "demo"]]
  let git_dir = (^git -C $existing rev-parse --absolute-git-dir | str trim)
  assert (not ($git_dir | path join "claude-code-worktree.json" | path exists))

  ^git -C $repo.app branch "worktree-demo"
  let branch_collision = (invoke $payload {})
  assert equal $branch_collision.run.exit_code 1
  assert equal $branch_collision.run.stdout ""
  assert ($branch_collision.run.stderr | str contains "Branch worktree-demo already exists")
  assert equal ($branch_collision.calls | get args) [["path" "demo"]]
}

def "test create refuses ownership when a branch appears during provisioning" [] {
  let repo = (setup-repo (mktemp --directory))
  let created = ($repo.root | path join "app__worktrees/demo")

  let result = (
    invoke {
      name: "demo"
      cwd: $repo.app
      session_id: $SESSION_ID
    } {
      STUB_ADD_PATH: $created
      STUB_ADD_EXISTING: "1"
    }
  )

  assert equal $result.run.exit_code 1
  assert equal $result.run.stdout ""
  assert ($result.run.stderr | str contains "Workmux checked out an existing branch")
  let git_dir = (^git -C $created rev-parse --absolute-git-dir | str trim)
  assert (not ($git_dir | path join "claude-code-worktree.json" | path exists))
}
