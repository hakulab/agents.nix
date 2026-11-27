# ==================================================================================================
# Claude Code Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
  resolved,
  scriptsDir,
  hooksCfg,
}:

let
  sharedHooks = resolved.mkHooks {
    assistant = "claude-code";
    toolClasses = {
      fileWrite = [
        "Edit"
        "Write"
      ];
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Assistant-specific hooks
  # ------------------------------------------------------------------------------------------------
  autoDream = import ./auto-dream.nix {
    inherit
      pkgs
      lib
      agentsLib
      scriptsDir
      ;
    inherit (sharedHooks) mkNuHook timeouts;
  };

  teammateIdle = import ./teammate-idle.nix {
    inherit scriptsDir;
    inherit (sharedHooks) mkNuHook;
  };

  worktree = import ./worktree.nix {
    inherit pkgs scriptsDir;
    inherit (sharedHooks) mkNuHook;
    inherit (hooksCfg.worktree) workmuxPackage;
  };

  # ------------------------------------------------------------------------------------------------
  # Installed hooks and notification events
  # ------------------------------------------------------------------------------------------------
  installed = sharedHooks.install (
    lib.optional hooksCfg.autoFormat.enable sharedHooks.hooks.autoFormat
    ++ lib.optional hooksCfg.commentGate.enable sharedHooks.hooks.commentGate
    ++ lib.optional hooksCfg.completeness.enable sharedHooks.hooks.completeness
    ++ lib.optional hooksCfg.autoDream.enable autoDream
    ++ lib.optional hooksCfg.teammateIdle.enable teammateIdle
    ++ lib.optionals hooksCfg.worktree.enable worktree
  );

  projectNotify = resolved.notify.mkProjectNotifyScript;

  ownEvents = lib.optionalAttrs hooksCfg.notify.enable {
    PermissionRequest = [
      {
        matcher = "AskUserQuestion";
        hooks = [
          {
            type = "command";
            command = "${projectNotify} --app claude --stdin 'Claude Code' 'Question asked'";
          }
        ];
      }
    ];

    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = "${projectNotify} --app claude --claude-stop 'Claude Code' 'Response complete'";
          }
        ];
      }
    ];
  };
in
{
  events = lib.zipAttrsWith (_: lib.concatLists) [
    installed.events
    ownEvents
  ];

  inherit (installed) dataFiles;
}
