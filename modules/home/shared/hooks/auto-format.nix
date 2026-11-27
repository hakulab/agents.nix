# ==================================================================================================
# Auto-Format Hook
# ==================================================================================================

{
  scriptsDir,
  mkNuHook,
  fileFormatter,
  patchInput,
  timeouts,
}:

{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  timeout = timeouts.postEdit;
  statusMessage = "Formatting edited files";
  command = mkNuHook {
    slug = "auto-format";
    script = scriptsDir + "/hooks/auto-format/auto-format.nu";
    config = {
      inherit fileFormatter patchInput;
    };
  };
}
