# ==================================================================================================
# Claude Code Teammate-Idle Hook
# ==================================================================================================

{
  scriptsDir,
  mkNuHook,
}:

{
  event = "TeammateIdle";
  type = "command";
  command = mkNuHook {
    slug = "teammate-idle";
    script = scriptsDir + "/claude-code/hooks/teammate-idle/teammate-idle.nu";
  };
}
