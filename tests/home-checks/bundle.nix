# ==================================================================================================
# Default Home Manager Bundle Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
}:

let
  inherit (harness) check evalModules;

  stubClaude = pkgs.writeShellScriptBin "claude" ''
    exit 0
  '';

  stubWorkmux = pkgs.writeShellScriptBin "workmux" ''
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

        omp.enable = true;
        agy.enable = true;
        oxide-code.enable = true;

        acp.enable = true;
        activity-report.enable = true;
        agent-project-move.enable = true;
        ccusage.enable = true;
        ctx7.enable = true;
        t3code.enable = true;

        workmux = {
          enable = true;
          package = stubWorkmux;
        };
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

  codexOnlyCfg = evalModules [
    homeModules.default
    {
      agents.codex.enable = true;
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
      !defaultDisabledCfg.agents.claude-code.enable
      && !defaultDisabledCfg.agents.codex.enable
      && !defaultDisabledCfg.agents.omp.enable
      && !defaultDisabledCfg.agents.agy.enable
      && !defaultDisabledCfg.agents.oxide-code.enable
      && !defaultDisabledCfg.agents.acp.enable
      && !defaultDisabledCfg.agents.activity-report.enable
      && !defaultDisabledCfg.agents.agent-project-move.enable
      && !defaultDisabledCfg.agents.ccusage.enable
      && !defaultDisabledCfg.agents.ctx7.enable
      && !defaultDisabledCfg.agents.t3code.enable
      && !defaultDisabledCfg.agents.workmux.enable
      && !defaultDisabledCfg.programs.claude-code.enable
      && !defaultDisabledCfg.programs.codex.enable
      && !defaultDisabledCfg.programs.antigravity-cli.enable
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
      && combinedCfg.programs.antigravity-cli.enable
      && combinedCfg.programs.oxide-code.enable
      && combinedCfg.programs.activity-report.enable
      && combinedCfg.programs.agent-project-move.enable
      && combinedCfg.xdg.configFile ? "claude/ccusage.json"
      && combinedCfg.xdg.configFile ? "workmux/config.yaml"
      && combinedCfg.home.file ? ".omp/agent/extensions/workmux-status.ts"
      && combinedCfg.agents.acp.claudeAdapter.executable != null
      && combinedCfg.agents.acp.codexAdapter.executable != null
      && combinedCfg.agents.acp.agyAdapter.enable
      &&
        lib.count (pkg: pkg == combinedCfg.programs.antigravity-cli.package) combinedCfg.home.packages == 1
      && combinedCfg.programs.activity-report.settings.excluded_dirs == [ "/[^/]+__worktrees/workmux-" ]
      && lib.all (a: a.assertion) combinedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Workmux + Claude Code / Codex integration
  # ------------------------------------------------------------------------------------------------
  {
    name = "workmux enables Claude Code workmux-status plugin and shares workmuxPackage";
    ok =
      combinedCfg.agents.claude-code.plugins.marketplaces ? workmux
      && combinedCfg.agents.claude-code.plugins.enabled."workmux-status@workmux"
      && combinedCfg.agents.claude-code.hooks.worktree.workmuxPackage == stubWorkmux;
  }
  {
    name = "workmux installs Codex status hooks by default when both modules are enabled";
    ok =
      combinedCfg.agents.workmux.installCodexHooks
      && hasHookCommand "workmux register-agent" combinedCfg.agents.codex.finalSettings.hooks.SessionStart
      && hasHookCommand "workmux set-window-status done" combinedCfg.agents.codex.finalSettings.hooks.Stop
      && hasHookCommand "echo custom-stop" combinedCfg.agents.codex.finalSettings.hooks.Stop;
  }
  {
    name = "workmux omits Codex status hooks when installCodexHooks is false";
    ok =
      !codexHooksOptOutCfg.agents.workmux.installCodexHooks
      && !(hasHookCommand "workmux register-agent" (
        codexHooksOptOutCfg.agents.codex.finalSettings.hooks.SessionStart or [ ]
      ))
      && !(codexHooksOptOutCfg.agents.codex.finalSettings.hooks ? Stop)
      && lib.all (a: a.assertion) codexHooksOptOutCfg.assertions;
  }
  {
    name = "codex without workmux enabled does not receive Workmux status hooks";
    ok =
      !codexOnlyCfg.agents.workmux.enable
      && !(hasHookCommand "workmux register-agent" (
        codexOnlyCfg.agents.codex.finalSettings.hooks.SessionStart or [ ]
      ))
      && !(codexOnlyCfg.agents.codex.finalSettings.hooks ? Stop)
      && lib.all (a: a.assertion) codexOnlyCfg.assertions;
  }
]
