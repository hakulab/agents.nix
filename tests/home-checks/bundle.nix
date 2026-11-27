# ==================================================================================================
# Default Home Manager Bundle Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  evalModules,
  homeModules,
}:

let
  stubClaude = pkgs.writeShellScriptBin "claude" ''
    exit 0
  '';

  sharedOnlyCfg = evalModules [ homeModules.shared ];
  defaultDisabledCfg = evalModules [ homeModules.default ];

  deduplicatedCfg = evalModules [
    homeModules.default
    homeModules.shared
    homeModules.codex
    homeModules.workmux
  ];

  combinedCfg = evalModules [
    homeModules.default
    {
      agents = {
        acp.enable = true;
        activity-report.enable = true;
        agent-project-move.enable = true;
        ccusage.enable = true;
        claude-code = {
          enable = true;
          package = stubClaude;
        };
        codex = {
          enable = true;
          hooks.extraEvents.Stop = [
            {
              hooks = [
                {
                  type = "command";
                  command = "echo custom-stop";
                }
              ];
            }
          ];
        };
        ctx7.enable = true;
        omp.enable = true;
        oxide-code.enable = true;
        t3code.enable = true;
        workmux.enable = true;
      };
    }
  ];

  codexHooksOptOutCfg = evalModules [
    homeModules.default
    {
      agents = {
        codex.enable = true;
        workmux = {
          enable = true;
          installCodexHooks = false;
        };
      };
    }
  ];

  hasHookCommand =
    command: entries:
    lib.any (entry: lib.any (hook: (hook.command or "") == command) (entry.hooks or [ ])) entries;
in
check "home-default" [
  # ------------------------------------------------------------------------------------------------
  # Default disabled state
  # ------------------------------------------------------------------------------------------------
  {
    name = "homeModules.default keeps every assistant and peripheral tool disabled by default";
    ok =
      !defaultDisabledCfg.agents.acp.enable
      && !defaultDisabledCfg.agents.activity-report.enable
      && !defaultDisabledCfg.agents.agent-project-move.enable
      && !defaultDisabledCfg.agents.ccusage.enable
      && !defaultDisabledCfg.agents.claude-code.enable
      && !defaultDisabledCfg.agents.codex.enable
      && !defaultDisabledCfg.agents.ctx7.enable
      && !defaultDisabledCfg.agents.omp.enable
      && !defaultDisabledCfg.agents.oxide-code.enable
      && !defaultDisabledCfg.agents.t3code.enable
      && !defaultDisabledCfg.agents.workmux.enable
      && !defaultDisabledCfg.programs.claude-code.enable
      && !defaultDisabledCfg.programs.codex.enable
      && !defaultDisabledCfg.programs.oxide-code.enable
      && defaultDisabledCfg.home.packages == sharedOnlyCfg.home.packages
      && !(defaultDisabledCfg.xdg.configFile ? "workmux/config.yaml")
      && !(defaultDisabledCfg.xdg.configFile ? "claude/ccusage.json")
      && lib.all (a: a.assertion) defaultDisabledCfg.assertions;
  }
  {
    name = "importing homeModules.default alongside individual modules deduplicates cleanly";
    ok = !deduplicatedCfg.agents.codex.enable && lib.all (a: a.assertion) deduplicatedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Combined multi-assistant and tool evaluation
  # ------------------------------------------------------------------------------------------------
  {
    name = "enabling all assistants and tools together evaluates cleanly without conflicts";
    ok =
      combinedCfg.programs.claude-code.enable
      && combinedCfg.programs.codex.enable
      && combinedCfg.agents.omp.enable
      && combinedCfg.programs.oxide-code.enable
      && combinedCfg.programs.activity-report.enable
      && combinedCfg.programs.agent-project-move.enable
      && combinedCfg.xdg.configFile ? "claude/ccusage.json"
      && combinedCfg.xdg.configFile ? "workmux/config.yaml"
      && combinedCfg.home.file ? ".omp/agent/extensions/workmux-status.ts"
      && combinedCfg.agents.acp.claudeAdapter.executable != null
      && combinedCfg.agents.acp.codexAdapter.executable != null
      && combinedCfg.programs.activity-report.settings.excluded_dirs == [ "/[^/]+__worktrees/workmux-" ]
      && lib.all (a: a.assertion) combinedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Workmux + Codex hook integration
  # ------------------------------------------------------------------------------------------------
  {
    name = "workmux installs Codex status hooks by default when both modules are enabled";
    ok =
      combinedCfg.agents.workmux.installCodexHooks
      && hasHookCommand "workmux register-agent" combinedCfg.agents.codex._internal.settings.hooks.SessionStart
      && hasHookCommand "workmux set-window-status done" combinedCfg.agents.codex._internal.settings.hooks.Stop
      && hasHookCommand "echo custom-stop" combinedCfg.agents.codex._internal.settings.hooks.Stop;
  }
  {
    name = "workmux omits Codex status hooks when installCodexHooks is false";
    ok =
      !codexHooksOptOutCfg.agents.workmux.installCodexHooks
      && !(hasHookCommand "workmux register-agent" (
        codexHooksOptOutCfg.agents.codex._internal.settings.hooks.SessionStart or [ ]
      ))
      && !(codexHooksOptOutCfg.agents.codex._internal.settings.hooks ? Stop);
  }
]
