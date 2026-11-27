#!/usr/bin/env nu

# ==================================================================================================
# Worktree Remove Hook Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "worktree-remove.nu")
const SESSION_ID = "test-session"

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

def "test remove requires an owned worktree and matching branch and handle" [] {
  let cases = [
    {
      label: "removed"
      ownership: "worktree-demo"
      session_id: $SESSION_ID
      handle: "demo"
      remote_collision: false
      leaves: false
      exit_code: 0
      calls: [["list" "--json" "demo"] ["remove" "--force" "demo"]]
    }
    {
      label: "deferred"
      ownership: "worktree-demo"
      session_id: $SESSION_ID
      handle: "demo"
      remote_collision: false
      leaves: true
      exit_code: 1
      calls: [["list" "--json" "demo"] ["remove" "--force" "demo"]]
    }
    {
      label: "unowned"
      ownership: null
      session_id: $SESSION_ID
      handle: "demo"
      remote_collision: false
      leaves: true
      exit_code: 1
      calls: []
    }
    {
      label: "different session"
      ownership: "worktree-demo"
      session_id: "earlier-session"
      handle: "demo"
      remote_collision: false
      leaves: true
      exit_code: 1
      calls: []
    }
    {
      label: "different branch"
      ownership: "worktree-original"
      session_id: $SESSION_ID
      handle: "demo"
      remote_collision: false
      leaves: true
      exit_code: 1
      calls: []
    }
    {
      label: "different checkout"
      ownership: "worktree-demo"
      session_id: $SESSION_ID
      handle: "other"
      remote_collision: false
      leaves: true
      exit_code: 1
      calls: [["list" "--json" "demo"]]
    }
    {
      label: "remote handle collision"
      ownership: "worktree-demo"
      session_id: $SESSION_ID
      handle: "demo"
      remote_collision: true
      leaves: true
      exit_code: 1
      calls: [["list" "--json" "demo"]]
    }
  ]

  for case in $cases {
    let root = (mktemp --directory)
    let repo = ($root | path join "app")
    let worktree = ($root | path join "demo")
    ^git init --quiet --initial-branch main $repo
    (
      ^git -C $repo
        -c user.email=test@example.com
        -c user.name=Test
        commit
        --quiet
        --allow-empty
        --message "base"
    )
    ^git -C $repo worktree add --quiet -b "worktree-demo" $worktree

    if $case.ownership != null {
      let git_dir = (^git -C $worktree rev-parse --absolute-git-dir | str trim)
      {
        session_id: $SESSION_ID
        branch: $case.ownership
      }
      | to json --raw
      | save ($git_dir | path join "claude-code-worktree.json")
    }

    let result = (
      invoke {
        worktree_path: $worktree
        session_id: $case.session_id
      } {
        STUB_EXISTING_PATH: ($root | path join $case.handle)
        STUB_REMOTE_COLLISION: (if $case.remote_collision { "1" } else { "" })
        STUB_REMOVE_PATH: $worktree
        STUB_REMOVE_LEAVES: (if $case.leaves { "1" } else { "" })
      }
    )

    assert equal $result.run.exit_code $case.exit_code $"($case.label): ($result.run.stderr)"
    assert equal ($worktree | path exists) $case.leaves $case.label
    assert equal ($result.calls | each {|call| $call.args }) $case.calls $case.label
  }
}

def "test remove succeeds when the worktree is already gone" [] {
  let missing = (mktemp --directory | path join "demo")
  let result = (invoke {worktree_path: $missing} {})

  assert equal $result.run.exit_code 0
  assert equal $result.calls []
}
