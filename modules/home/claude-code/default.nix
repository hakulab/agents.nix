# ==================================================================================================
# Claude Code Home Manager Module (agents.claude-code)
# ==================================================================================================

{
  agentsLib,
  claudeStatuslineFor,
  claudeStatuslineModule,
  llmAgentsFor,
  repoRoot,
  sharedHomeModule,
}:

let
  assetsDir = repoRoot + "/assets";
  scriptsDir = repoRoot + "/scripts";
in
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.claude-code;
  resolved = config.agents.resolved;
  system = pkgs.stdenv.hostPlatform.system;

  enabledMcpServers = resolved.mcp.computeEnabledServers cfg.mcp;

  mcp = import ./mcp.nix {
    inherit pkgs resolved;
    enabledServers = enabledMcpServers;
  };

  # `--mcp-config` is variadic, so only the `=` form keeps it from swallowing the prompt.
  mcpFlag = "--mcp-config=${mcp.configFile}";

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      agentsLib
      resolved
      scriptsDir
      mcpFlag
      ;
    inherit (cfg.agents) enabledAgents;
  };
in
{
  imports = [
    sharedHomeModule
    claudeStatuslineModule
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.claude-code = {
    enable = lib.mkEnableOption "Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code or (llmAgentsFor system).claude-code;
      defaultText = lib.literalExpression "pkgs.claude-code or llm-agents.packages.\${system}.claude-code";
      description = "Base Claude Code package to wrap";
    };

    auth = profiles.options;

    agents = {
      enabledAgents = resolved.agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents enabled for Claude Code";
      };
    };

    mcp = resolved.mcp.mkMcpOptions {
      default = resolved.mcp.serverNames;
      description = "MCP servers for Claude Code";
    };

    hooks = {
      autoDream = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the SessionStart auto-dream memory consolidation hook";
        };
      };

      autoFormat = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the PostToolUse auto-format hook";
        };
      };

      commentGate = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the PostToolUse comment-gate hook when modelCall is enabled";
        };
      };

      completeness = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the Stop completeness prompt hook";
        };
      };

      notify = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable desktop notifications for Stop and AskUserQuestion hooks";
        };
      };

      teammateIdle = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the TeammateIdle nudge hook";
        };
      };

      worktree = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable WorktreeCreate and WorktreeRemove Workmux hooks";
        };

        workmuxPackage = lib.mkOption {
          type = lib.types.package;
          default = pkgs.workmux or (llmAgentsFor system).workmux;
          defaultText = lib.literalExpression "pkgs.workmux or llm-agents.packages.\${system}.workmux";
          description = "Workmux package used by Claude Code worktree hooks";
        };
      };
    };

    plugins = {
      marketplaces = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          claude-plugins-official = "anthropics/claude-plugins-official";
          workmux = "raine/workmux";
        };
        description = "GitHub plugin marketplaces keyed by marketplace name";
      };

      enabled = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = {
          "skill-creator@claude-plugins-official" = true;
          "workmux-status@workmux" = true;
        };
        description = "Plugins enabled in Claude Code settings";
      };

      lspPlugins = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable language-server plugins from claude-plugins-official";
      };
    };

    statusline = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable claude-statusline integration";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.claude-statusline or (claudeStatuslineFor system).claude-statusline;
        defaultText = lib.literalExpression "pkgs.claude-statusline or claude-statusline.packages.\${system}.claude-statusline";
        description = "Package providing the claude-statusline binary";
      };

      models = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Additional model ID to display name mappings merged onto catalog defaults";
      };

      costSources = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "External cost source entries written to claude-statusline settings";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Extra top-level settings merged into programs.claude-statusline.settings";
      };
    };

    extraInstructions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional Markdown instructions appended to ~/.claude/CLAUDE.md";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra settings recursively merged into ~/.claude/settings.json";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      json = pkgs.formats.json { };

      # --------------------------------------------------------------------------------------------
      # Subsystem assembly
      # --------------------------------------------------------------------------------------------
      hooks = import ./hooks.nix {
        inherit
          pkgs
          lib
          agentsLib
          resolved
          scriptsDir
          ;
        hooksCfg = cfg.hooks;
      };

      permissionSettings = import ./permissions.nix {
        inherit lib resolved;
      };

      plugins = import ./plugins.nix {
        inherit lib;
        pluginsCfg = cfg.plugins;
      };

      statusline = import ./statusline.nix {
        inherit lib resolved;
        statuslineCfg = cfg.statusline;
      };

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = profiles.wrapArgs ++ agentsLib.proxy.mkProxyWrapArgs config.agents.proxy;

      claudeCodeBin = agentsLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = cfg.package;
        name = "claude-code-${cfg.package.version or "wrapped"}";
        bin = "claude";
        envVars = {
          # Restores the upstream default, since nixpkgs narrows it to `system`, which loads only a
          # few Keychain roots in macOS SSH sessions.
          CLAUDE_CODE_CERT_STORE = "bundled,system";

          # The marketplaces are declared in settings, so the built-in snapshot install duplicates
          # their clone and fails when `downloads.claude.ai` is unreachable.
          CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL = "1";
        };
      };

      # --------------------------------------------------------------------------------------------
      # Configuration files
      # --------------------------------------------------------------------------------------------
      settingsJson = json.generate "claude-code-settings.json" (
        import ./settings.nix {
          inherit
            lib
            resolved
            hooks
            permissionSettings
            plugins
            ;
          profileSettings = profiles.settings;
          statuslineEnable = cfg.statusline.enable;
          inherit (cfg) extraSettings;
        }
        // {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
        }
      );

      # Editor file watchers resolve symlinks and watch the parent directory, which must not be
      # /nix/store itself.
      configFiles = pkgs.runCommand "claude-code-config" { } ''
        set -euo pipefail
        mkdir -p "$out"
        cp ${lib.escapeShellArg settingsJson} "$out/settings.json"
      '';

      claudeMdText = agentsLib.prompts.joinSections [
        resolved.instructions
        (builtins.readFile (assetsDir + "/instructions/claude-code.md"))
        cfg.extraInstructions
      ];

      unknownMcpServers = lib.filter (name: !(resolved.mcp.servers ? ${name})) enabledMcpServers;
    in
    lib.mkMerge [
      profiles.config

      {
        assertions = [
          {
            assertion = unknownMcpServers == [ ];
            message = "agents.claude-code.mcp.enabledServers references unknown or disabled servers: ${lib.concatStringsSep ", " unknownMcpServers}";
          }
        ];

        agents = {
          claude-code.mcp.disabledServers = lib.mkDefault resolved.mcp.disabledServers;
          skills.targets.claude = lib.mkDefault true;
        };

        programs = {
          claude-code = {
            enable = true;
            package = claudeCodeBin;
          };

          claude-statusline = statusline;
        };

        home.file = {
          ".claude/CLAUDE.md".text = claudeMdText;
          ".claude/settings.json".source = "${configFiles}/settings.json";
        };

        xdg.dataFile = hooks.dataFiles;
      }
    ]
  );
}
