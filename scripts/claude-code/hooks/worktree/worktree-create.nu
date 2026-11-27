#!/usr/bin/env nu

# ==================================================================================================
# Worktree Create Hook
# ==================================================================================================
# Claude Code hands this hook the worktree name and the session's working directory, and reads the
# absolute path it prints as the worktree to enter. Workmux records the handle, branch, and base
# for later cleanup.
# ==================================================================================================

# The commit a new worktree branches from, without fetching.
def base-ref [cwd: string]: nothing -> string {
  let remote = (^git -C $cwd rev-parse --abbrev-ref origin/HEAD | complete)
  if $remote.exit_code == 0 {
    $remote.stdout | str trim
  } else {
    ^git -C $cwd rev-parse HEAD | str trim
  }
}

def main [] {
  let input = (^cat | from json)
  let session_id = $input.session_id
  if ($session_id | is-empty) {
    error make {msg: "Claude Code did not provide a worktree session ID."}
  }

  cd $input.cwd

  let branch = $"worktree-($input.name)"
  let existing = (^workmux path $input.name | complete)
  if (
    $existing.exit_code == 0
    and (($existing.stdout | str trim | path basename) == $input.name)
  ) {
    error make {msg: $"Worktree ($input.name) already exists. Choose another name."}
  }
  if (^git show-ref --verify --quiet $"refs/heads/($branch)" | complete).exit_code == 0 {
    error make {msg: $"Branch ($branch) already exists. Choose another worktree name."}
  }

  let base = (base-ref $input.cwd)
  # Like Claude's built-in creation, skip repository-defined post-create hooks.
  let receipt = (
    ^workmux add $branch
      --base $base
      --name $input.name
      --no-hooks
      --headless
      --json
    | from json
  )
  # Workmux returns a null base when it checks out a branch created by another process.
  if $receipt.base_branch == null {
    error make {
      msg: $"Workmux checked out an existing branch at ($receipt.worktree_path). Inspect the checkout before removing it manually."
    }
  }

  let git_dir = (^git -C $receipt.worktree_path rev-parse --absolute-git-dir | str trim)
  {
    session_id: $session_id
    branch: $branch
  }
  | to json --raw
  | save ($git_dir | path join "claude-code-worktree.json")
  print $receipt.worktree_path
}
