#!/usr/bin/env nu

# ==================================================================================================
# Workmux Stub
# ==================================================================================================
# Records each invocation and provisions fixtures under the test's scratch repository.
# ==================================================================================================

def --wrapped main [...args: string] {
  {
    cwd: $env.PWD
    args: $args
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  let command = ($args | get -o 0 | default "")
  match $command {
    "path" => {
      let path = ($env.STUB_EXISTING_PATH? | default "")
      if ($path | is-empty) {
        print --stderr "Worktree not found"
        exit 1
      }
      print $path
    }
    "add" => {
      let branch = ($args | get 1)
      let base = ($args | get 3)
      let path = $env.STUB_ADD_PATH
      let existing = ($env.STUB_ADD_EXISTING? | default "") == "1"

      if $existing {
        ^git branch $branch $base
        ^git worktree add --quiet $path $branch
      } else {
        ^git worktree add --quiet -b $branch $path $base
      }

      {
        schema_version: 1
        worktree_path: $path
        base_branch: (if $existing { null } else { $base })
      }
      | to json --raw
    }
    "remove" => {
      let leaves = ($env.STUB_REMOVE_LEAVES? | default "")
      if ($leaves | is-empty) {
        ^rm -rf $env.STUB_REMOVE_PATH
        exit 0
      }
    }
    _ => {}
  }
}
