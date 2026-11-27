# ==================================================================================================
# Workmux Agent Orchestration Module (agents.workmux)
# ==================================================================================================

{
  sharedModule,
  llmAgentsPackagesFor,
}:

{
  config,
  options,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.workmux;
  llmAgentsPackages = llmAgentsPackagesFor pkgs.stdenv.hostPlatform.system;
  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "workmux-config.yaml" cfg.settings;

  workmuxCodexHooks =
    (lib.importJSON "${cfg.package.src}/resources/codex/hooks/workmux-status.json").hooks;

  workmuxSkills = [
    "coordinator"
    "merge"
    "rebase"
    "workmux"
    "worktree"
  ];

  workmuxSkillFiles = lib.genAttrs' workmuxSkills (
    name:
    lib.nameValuePair ".agents/skills/${name}" {
      source = "${cfg.package}/share/skills/workmux/${name}";
    }
  );
in
{
  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.workmux = {
    enable = lib.mkEnableOption "Workmux agent orchestration";

    package = lib.mkOption {
      type = lib.types.package;
      default = llmAgentsPackages.workmux;
      description = "Package providing the workmux CLI and bundled skills";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = yaml.type;
        options = {
          nerdfont = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Use Nerd Font icons in Workmux status output";
          };

          status_format = lib.mkOption {
            type = lib.types.either lib.types.bool lib.types.str;
            default = false;
            description = "tmux window status format override, or false to keep theme formatting";
          };

          worktree_prefix = lib.mkOption {
            type = lib.types.str;
            default = "workmux-";
            description = "Prefix added to Workmux-managed worktree directories";
          };
        };
      };
      default = { };
      description = "Settings written to workmux/config.yaml in the XDG config directory";
    };

    installSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install bundled Workmux skills under ~/.agents/skills";
    };

    installCodexHooks = lib.mkOption {
      type = lib.types.bool;
      default = config.agents.codex.enable or false;
      description = "Install Workmux status hooks into Codex";
    };

    installOmpExtension = lib.mkOption {
      type = lib.types.bool;
      default = config.agents.omp.enable or false;
      description = "Install the Workmux status extension for Oh My Pi";
    };

    tmuxIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add Workmux status to Catppuccin tmux windows and bind the dashboard popup";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];

        home.file =
          lib.optionalAttrs cfg.installSkills workmuxSkillFiles
          // lib.optionalAttrs cfg.installOmpExtension {
            ".omp/agent/extensions/workmux-status.ts".source =
              "${cfg.package.src}/resources/omp/extensions/workmux-status.ts";
          };

        xdg.configFile."workmux/config.yaml".source = configFile;
      }

      (lib.optionalAttrs (options.agents ? codex) {
        agents.codex.hooks.extraEvents = lib.mkIf cfg.installCodexHooks workmuxCodexHooks;
      })

      (lib.mkIf cfg.tmuxIntegration {
        programs.tmux.extraConfig = lib.mkBefore ''
          set -ag @catppuccin_window_text "#{?@workmux_status, #{@workmux_status},}"
          set -ag @catppuccin_window_current_text "#{?@workmux_status, #{@workmux_status},}"
          bind g display-popup -EE -w 90% -h 90% 'workmux dashboard'
        '';
      })
    ]
  );
}
