# ==================================================================================================
# Claude Code Auto-Dream Hook
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
  scriptsDir,
  mkNuHook,
  timeouts,
}:

let
  hookDir = scriptsDir + "/claude-code/hooks/auto-dream";
in
{
  event = "SessionStart";
  type = "command";
  timeout = timeouts.tool;
  statusMessage = "Checking memory consolidation";
  command = mkNuHook {
    slug = "auto-dream";
    script = hookDir + "/auto-dream.nu";
    config = {
      git = lib.getExe pkgs.git;
      model = agentsLib.models.modelAliases.claude.flagship;
      prompt = builtins.readFile (hookDir + "/prompt.md");
    };
  };
}
