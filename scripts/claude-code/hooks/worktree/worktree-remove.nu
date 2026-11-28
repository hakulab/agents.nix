#!/usr/bin/env nu

# ==================================================================================================
# Worktree Remove Hook
# ==================================================================================================
# Remove a worktree and branch provisioned by the create hook.
# ==================================================================================================

def main [] {
  let input = (^cat | from json)
  let worktree = ($input.worktree_path | path expand)

  if not ($worktree | path exists) {
    exit 0
  }

  let git_dir = (^git -C $worktree rev-parse --absolute-git-dir | str trim)
  let marker = ($git_dir | path join "claude-code-worktree.json")
  if not ($marker | path exists) {
    error make {msg: $"Worktree ($worktree) has no ownership record. Inspect it before removing it manually."}
  }

  let owner = (open $marker)
  if $owner.session_id != $input.session_id {
    error make {msg: $"Worktree ($worktree) belongs to a different Claude Code session."}
  }

  let head = (^git -C $worktree symbolic-ref --quiet HEAD | complete)
  if $head.exit_code != 0 or ($head.stdout | str trim) != $"refs/heads/($owner.branch)" {
    error make {msg: $"Worktree ($worktree) has changed branches. Inspect it before removing it manually."}
  }

  let handle = ($worktree | path basename)
  do {
    cd $worktree
    # Workmux resolves remote handles before local targets on removal.
    let targets = (
      ^workmux list --json $handle
      | from json
      | where {|target| $target.handle == $handle }
    )
    if (
      ($targets | length) != 1
      or $targets.0.remote? != null
      or ($targets.0.path | path expand) != $worktree
    ) {
      error make {msg: $"Workmux could not uniquely resolve ($handle) to ($worktree). Inspect it before removing it manually."}
    }

    ^workmux remove --force $handle
  }

  if ($worktree | path exists) {
    error make {msg: $"Worktree ($worktree) still exists. Inspect it before removing it manually."}
  }
}
