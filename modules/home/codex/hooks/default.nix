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

  compactContext = import ./compact-context.nix {
    inherit scriptsDir;
    inherit (sharedHooks) mkNuHook timeouts;
  };

  installed = sharedHooks.install (
    lib.optional hooksCfg.autoFormat.enable sharedHooks.hooks.autoFormat
    ++ lib.optional hooksCfg.commentGate.enable sharedHooks.hooks.commentGate
    ++ lib.optional hooksCfg.compactContext.enable compactContext
  );
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    installed.events
    hooksCfg.extraEvents
  ];

  inherit (installed) dataFiles;
}
