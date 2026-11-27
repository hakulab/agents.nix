# ==================================================================================================
# Claude Code Worktree Hooks
# ==================================================================================================

{
  pkgs,
  scriptsDir,
  mkNuHook,
  workmuxPackage,
}:

let
  hookDir = scriptsDir + "/claude-code/hooks/worktree";

  runtimeInputs = [
    pkgs.git
    workmuxPackage
  ];
in
[
  {
    event = "WorktreeCreate";
    type = "command";
    command = mkNuHook {
      slug = "worktree-create";
      script = hookDir + "/worktree-create.nu";
      inherit runtimeInputs;
    };
  }

  {
    event = "WorktreeRemove";
    type = "command";
    command = mkNuHook {
      slug = "worktree-remove";
      script = hookDir + "/worktree-remove.nu";
      inherit runtimeInputs;
    };
  }
]
