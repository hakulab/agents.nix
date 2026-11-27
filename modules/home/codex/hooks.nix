# ==================================================================================================
# Codex Hooks
# ==================================================================================================

{
  lib,
  resolved,
  scriptsDir,
  hooksCfg,
}:

let
  sharedHooks = resolved.mkHooks {
    assistant = "codex";
    toolClasses = {
      fileWrite = [
        "Edit"
        "Write"
        "^apply_patch$"
      ];
    };
  };

  compactContextDir = scriptsDir + "/hooks/codex/compact-context";

  compactContext = {
    event = "SessionStart";
    type = "command";
    matcher = "compact";
    timeout = sharedHooks.timeouts.tool;
    statusMessage = "Restoring compacted context";
    command = sharedHooks.mkNuHook {
      slug = "compact-context";
      script = compactContextDir + "/compact-context.nu";
      config = {
        prompt = builtins.readFile (compactContextDir + "/prompt.md");
      };
    };
  };

  installed = sharedHooks.install (
    lib.optional hooksCfg.compactContext.enable compactContext
    ++ lib.optional hooksCfg.autoFormat.enable sharedHooks.hooks.autoFormat
    ++ lib.optional hooksCfg.commentGate.enable sharedHooks.hooks.commentGate
  );
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    installed.events
    hooksCfg.extraEvents
  ];

  inherit (installed) dataFiles;
}
