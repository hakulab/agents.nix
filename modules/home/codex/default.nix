# ==================================================================================================
# Codex Home Manager Module (agents.codex)
# ==================================================================================================

{
  devkit,
  llm-agents,
  agentsLib,
  repoRoot,
  sharedModule,
}:

let
  scriptsDir = repoRoot + "/scripts";
in
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.codex;
  resolved = config.agents.resolved;
  configDir = resolved.configDirs.codex;
  dk = devkit.lib.mkLib pkgs;
  inherit (config.agents._internal) nuModules;
  json = pkgs.formats.json { };

  defaultPlugins = import ./plugins.nix {
    inherit pkgs lib;
  };
in
{
  key = "agents-nix/home/codex";

  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.codex = {
    enable = lib.mkEnableOption "Codex CLI and Home Manager configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      defaultText = lib.literalExpression "llm-agents.packages.\${system}.codex";
      description = "Codex CLI package to wrap and install";
    };

    auth =
      agentsLib.profiles.mkOptions {
        defaultProfile = "official";
      }
      // {
        allowedProviders = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "Optional allowlist of provider names exposed to Codex profiles";
        };

        allowedChannels = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "Optional allowlist of provider channels exposed to Codex profiles";
        };
      };

    agents = {
      enabledAgents = resolved.agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable for Codex";
      };
    };

    mcp = agentsLib.mcp.mkMcpOptions {
      default = resolved.mcp.serverNames;
      description = "Codex MCP servers";
    };

    hooks = {
      autoFormat.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the post-edit auto-format hook";
      };

      commentGate.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the comment-gate hook when agents.modelCall is enabled";
      };

      compactContext.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the SessionStart hook that restores file context after compaction";
      };

      extraEvents = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
        default = { };
        description = "Additional Codex hook event entries merged into config.toml";
      };
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether this Codex plugin is enabled";
          };
        }
      );
      default = { };
      description = "Codex plugin enablement table merged into config.toml";
    };

    rulesFileName = lib.mkOption {
      type = lib.types.str;
      default = "agents-nix.rules";
      description = "Filename under the Codex rules directory for managed permission rules";
    };

    desktop = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = pkgs.stdenv.isDarwin;
        description = "Manage Codex desktop preferences and Chronicle feature flag";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Overrides recursively merged onto the default Codex desktop settings";
      };
    };

    keybindings = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = lib.optionals pkgs.stdenv.isDarwin [
        {
          command = "hotkeyWindow";
          key = "Command+Shift+Space";
        }
      ];
      description = "Codex desktop keybindings merged into keybindings.json";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra settings recursively merged into Codex config.toml";
    };

    _internal = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      internal = true;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # --------------------------------------------------------------------------------------------
      # Submodule assembly
      # --------------------------------------------------------------------------------------------
      profiles = import ./profiles.nix {
        inherit
          config
          pkgs
          lib
          agentsLib
          ;
      };

      desktopDefaults = import ./desktop.nix {
        homeDir = config.home.homeDirectory;
      };

      desktopSettings = lib.optionalAttrs cfg.desktop.enable {
        desktop = lib.recursiveUpdate desktopDefaults cfg.desktop.settings;
        features.chronicle = true;
      };

      hooks = import ./hooks.nix {
        inherit lib resolved scriptsDir;
        hooksCfg = cfg.hooks;
      };

      permissions = import ./permissions.nix {
        inherit lib resolved;
      };

      mcp = import ./mcp.nix {
        inherit lib resolved;
        inherit (permissions) mcpApprovals;
        enabledServers = agentsLib.mcp.computeEnabledServers cfg.mcp;
      };

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      codexVersion =
        let
          v = lib.getVersion cfg.package;
        in
        if v != "" then v else "0.94.0";

      # Home Manager uses the version in the name to select the config layout.
      codexBin = agentsLib.wrapPackage {
        inherit pkgs;
        pkg = cfg.package;
        name = "codex-${codexVersion}";
        bin = "codex";
        wrapArgs =
          lib.optionals pkgs.stdenv.isLinux [
            "--suffix"
            "PATH"
            ":"
            (lib.makeBinPath [ pkgs.bubblewrap ])
          ]
          ++ agentsLib.proxy.mkProxyWrapArgs config.agents.proxy;
        inherit (profiles) envVars envFiles;
      };

      # --------------------------------------------------------------------------------------------
      # Config activation
      # --------------------------------------------------------------------------------------------
      baseSettings =
        (import ./settings.nix {
          inherit
            resolved
            hooks
            mcp
            permissions
            ;
        })
        // profiles.settings
        // lib.optionalAttrs (cfg.plugins != { }) {
          inherit (cfg) plugins;
        };

      codexSettings = lib.recursiveUpdate (lib.recursiveUpdate baseSettings desktopSettings) cfg.extraSettings;

      activateConfig = dk.writeNuApplication {
        name = "activate-codex-config";
        text = builtins.readFile (scriptsDir + "/codex/activate-config.nu");
        runtimeInputs = [ pkgs.coreutils ];
        libDirs = [ nuModules ];
        flags.config = json.generate "activate-codex-config.json" {
          inherit configDir;
          activeProfile = "${profiles.stateDir}/active-profile";
          settings = codexSettings;
          inherit (cfg) keybindings;
        };
      };

      stopStaleDaemon = dk.writeNuApplication {
        name = "stop-stale-codex-daemon";
        text = builtins.readFile (scriptsDir + "/codex/stop-stale-daemon.nu");
        runtimeInputs = [ codexBin ];
        flags.package = cfg.package;
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Assertions
        # ------------------------------------------------------------------------------------------
        assertions = [
          {
            assertion = mcp.missingServers == [ ];
            message = "Codex: agents.codex.mcp.enabledServers references unavailable MCP server(s): ${lib.concatStringsSep ", " mcp.missingServers}";
          }
        ];

        # ------------------------------------------------------------------------------------------
        # Shared integration
        # ------------------------------------------------------------------------------------------
        agents = {
          codex = {
            mcp.disabledServers = lib.mkDefault config.agents.mcp.disabledServers;
            plugins = lib.mapAttrs (_: plugin: { enabled = lib.mkDefault plugin.enabled; }) defaultPlugins;

            _internal = {
              settings = codexSettings;
              inherit (profiles)
                envFiles
                envVars
                profiles
                stateDir
                ;
            };
          };

          skills.targets.codex = lib.mkDefault true;
        };

        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        programs.codex = {
          enable = true;
          package = codexBin;
          context = resolved.instructions;
        };

        # ------------------------------------------------------------------------------------------
        # Configuration files and activation
        # ------------------------------------------------------------------------------------------
        home = {
          file = {
            codexRules = {
              # Separate from default.rules, which Codex rewrites on TUI allowlisting.
              target = "${configDir}/rules/${cfg.rulesFileName}";
              text = permissions.rules;
            };
          };

          activation = {
            codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              run ${lib.getExe activateConfig}
            '';

            codexDaemon = lib.hm.dag.entryAfter [ "codexAuthProfile" ] ''
              run ${lib.getExe stopStaleDaemon}
            '';
          };
        };

        xdg.dataFile = hooks.dataFiles;
      }
    ]
  );
}
