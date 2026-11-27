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
  hooksDir = scriptsDir + "/hooks/claude-code";

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
  autoDream = {
    event = "SessionStart";
    type = "command";
    timeout = sharedHooks.timeouts.tool;
    statusMessage = "Checking memory consolidation";
    command = sharedHooks.mkNuHook {
      slug = "auto-dream";
      script = hooksDir + "/auto-dream/auto-dream.nu";
      config = {
        git = lib.getExe pkgs.git;
        model = agentsLib.models.modelAliases.claude.flagship;
        prompt = builtins.readFile (hooksDir + "/auto-dream/prompt.md");
      };
    };
  };

  teammateIdle = {
    event = "TeammateIdle";
    type = "command";
    command = sharedHooks.mkNuHook {
      slug = "teammate-idle";
      script = hooksDir + "/teammate-idle/teammate-idle.nu";
    };
  };

  worktreeRuntimeInputs = [
    pkgs.git
    hooksCfg.worktree.workmuxPackage
  ];

  worktreeCreate = {
    event = "WorktreeCreate";
    type = "command";
    command = sharedHooks.mkNuHook {
      slug = "worktree-create";
      script = hooksDir + "/worktree/worktree-create.nu";
      runtimeInputs = worktreeRuntimeInputs;
    };
  };

  worktreeRemove = {
    event = "WorktreeRemove";
    type = "command";
    command = sharedHooks.mkNuHook {
      slug = "worktree-remove";
      script = hooksDir + "/worktree/worktree-remove.nu";
      runtimeInputs = worktreeRuntimeInputs;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Installed hooks and notification events
  # ------------------------------------------------------------------------------------------------
  installed = sharedHooks.install (
    lib.optional hooksCfg.autoDream.enable autoDream
    ++ lib.optional hooksCfg.autoFormat.enable sharedHooks.hooks.autoFormat
    ++ lib.optional hooksCfg.commentGate.enable sharedHooks.hooks.commentGate
    ++ lib.optional hooksCfg.completeness.enable sharedHooks.hooks.completeness
    ++ lib.optional hooksCfg.teammateIdle.enable teammateIdle
    ++ lib.optionals hooksCfg.worktree.enable [
      worktreeCreate
      worktreeRemove
    ]
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
