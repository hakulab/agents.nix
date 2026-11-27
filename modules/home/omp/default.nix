# ==================================================================================================
# OMP Home Manager Module (agents.omp)
# ==================================================================================================

{
  llm-agents,
  agentsLib,
  repoRoot,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.omp;
  resolved = config.agents.resolved;
  inherit (resolved) agentRoleOptions instructions;

  extensions = import ./extensions.nix {
    inherit pkgs;
  };

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      agentsLib
      ;
  };
in
{
  imports = [
    sharedModule
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.omp = {
    enable = lib.mkEnableOption "Oh My Pi (omp) coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
      defaultText = lib.literalExpression "inputs.llm-agents.packages.\${system}.omp";
      description = "Oh My Pi package to wrap and install";
    };

    auth = profiles.options;

    agents = {
      enabledAgents = agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable for OMP";
      };
    };

    mcp = resolved.mcp.mkMcpOptions {
      default = resolved.mcp.serverNames;
      description = "MCP servers for OMP";
    };

    extensions = {
      fileFormatter = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the file-formatter OMP extension";
        };
      };

      telegram = {
        enable = lib.mkEnableOption "omp-telegram extension";

        package = lib.mkOption {
          type = lib.types.package;
          default = extensions.telegram;
          defaultText = lib.literalExpression "pkgs.fetchFromGitHub { ... }";
          description = "Source package for the omp-telegram extension";
        };

        botTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Runtime file path containing the Telegram bot token";
        };
      };
    };

    extraEnvFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables loaded from runtime file paths when launching omp";
    };

    watchdogText = lib.mkOption {
      type = lib.types.lines;
      default = builtins.readFile (repoRoot + "/assets/instructions/omp-watchdog.md");
      description = "Contents of ~/.omp/agent/WATCHDOG.md";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra OMP settings recursively merged into omp-settings.yml";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      json = pkgs.formats.json { };
      yaml = pkgs.formats.yaml { };

      # --------------------------------------------------------------------------------------------
      # Submodule outputs
      # --------------------------------------------------------------------------------------------
      agents = import ./agents.nix {
        inherit lib resolved;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ./mcp.nix {
        inherit lib resolved;
        enabledServers = resolved.mcp.computeEnabledServers cfg.mcp;
      };

      baseSettings = import ./settings.nix {
        inherit resolved;
      };

      settingsConfigFile = yaml.generate "omp-settings.yml" (
        lib.recursiveUpdate baseSettings cfg.extraSettings
      );

      permissionConfigFile = yaml.generate "omp-permissions.yml" (
        import ./permissions.nix {
          inherit lib resolved;
        }
      );

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          pkgs.bun
          pkgs.poppler-utils
        ])
      ]
      ++ agentsLib.proxy.mkProxyWrapArgs config.agents.proxy
      ++ [
        "--add-flags"
        "--config ${settingsConfigFile}"

        "--add-flags"
        "--config ${permissionConfigFile}"
      ];

      envVars =
        profiles.envVars
        // lib.optionalAttrs (config.agents.browser.chromiumPackage != null) {
          PUPPETEER_EXECUTABLE_PATH = lib.getExe config.agents.browser.chromiumPackage;
        };

      envFiles =
        lib.optionalAttrs (cfg.extensions.telegram.enable && cfg.extensions.telegram.botTokenFile != null) {
          TELEGRAM_BOT_TOKEN = cfg.extensions.telegram.botTokenFile;
        }
        // cfg.extraEnvFiles;

      ompBin = agentsLib.wrapPackage {
        inherit pkgs;
        pkg = cfg.package;
        bin = "omp";
        inherit wrapArgs envVars envFiles;
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Shared integration
        # ------------------------------------------------------------------------------------------
        agents = {
          omp.mcp.disabledServers = resolved.mcp.disabledServers;
          skills.targets.omp = lib.mkDefault true;
        };

        # ------------------------------------------------------------------------------------------
        # Packages and configuration files
        # ------------------------------------------------------------------------------------------
        home = {
          packages = [
            ompBin
          ];

          file = {
            ".omp/agent/AGENTS.md".text = instructions;
            ".omp/agent/WATCHDOG.md".text = cfg.watchdogText;
            ".omp/agent/mcp.json".source = json.generate "omp-mcp.json" { mcpServers = mcp.serversConfig; };
          }
          // lib.optionalAttrs cfg.extensions.fileFormatter.enable {
            ".omp/agent/extensions/file-formatter.ts".source =
              pkgs.replaceVars (repoRoot + "/scripts/omp/file-formatter.ts")
                {
                  fileFormatter = lib.getExe config.agents.hooks.fileFormatterPackage;
                };
          }
          // lib.optionalAttrs cfg.extensions.telegram.enable {
            ".omp/agent/extensions/omp-telegram".source = cfg.extensions.telegram.package;
          }
          // agents.homeFiles;
        };
      }
    ]
  );
}
