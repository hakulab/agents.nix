# ==================================================================================================
# Codex Compact-Context Hook
# ==================================================================================================

{
  scriptsDir,
  mkNuHook,
  timeouts,
}:

let
  hookDir = scriptsDir + "/codex/hooks/compact-context";
in
{
  event = "SessionStart";
  type = "command";
  matcher = "compact";
  timeout = timeouts.tool;
  statusMessage = "Restoring compacted context";
  command = mkNuHook {
    slug = "compact-context";
    script = hookDir + "/compact-context.nu";
    config = {
      prompt = builtins.readFile (hookDir + "/prompt.md");
    };
  };
}
