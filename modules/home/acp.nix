# ==================================================================================================
# Agent Client Protocol (ACP) Module (agents.acp)
# ==================================================================================================

{
  self,
  llm-agents,
  agentsLib,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.acp;
  system = pkgs.stdenv.hostPlatform.system;
  selfPackages = self.packages.${system};
  llmAgentsPackages = llm-agents.packages.${system};
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Default executable detection
  # ------------------------------------------------------------------------------------------------
  # Session identity includes argv. Keep paths stable across rebuilds and upstream basenames intact
  # for adapter detection.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

  programPackage = program: if program.enable or false then program.package or null else null;

  programExecutable =
    name: program:
    let
      package = programPackage program;
    in
    if package != null then lib.getExe' package name else null;

  defaultClaudeExecutable = programExecutable "claude" (config.programs.claude-code or { });
  defaultCodexExecutable = programExecutable "codex" (config.programs.codex or { });

  defaultAgyExecutable =
    let
      package = programPackage (config.programs.antigravity-cli or { });
    in
    if package != null && lib.getName package != "gemini-cli" then profileBin "agy" else null;

  # ------------------------------------------------------------------------------------------------
  # Package wrappers
  # ------------------------------------------------------------------------------------------------
  # acpx skips user settings by default, dropping Claude hooks, permissions, and instructions.
  acpxBin = agentsLib.wrapPackage {
    inherit pkgs;
    pkg = cfg.package;
    bin = "acpx";
    envVars.ACPX_CLAUDE_INCLUDE_USER_SETTINGS = "1";
  };

  # Adapters export their resolved binary to child agents. Override inherited values so nested
  # delegation also uses wrapped assistant launchers when configured.
  mkAdapter =
    {
      pkg,
      bin,
      executableVar,
      executable,
    }:
    if executable != null then
      agentsLib.wrapPackage {
        inherit pkgs pkg bin;
        envVars.${executableVar} = executable;
      }
    else
      pkg;

  claudeAdapter = mkAdapter {
    pkg = cfg.claudeAdapter.package;
    bin = "claude-agent-acp";
    executableVar = "CLAUDE_CODE_EXECUTABLE";
    inherit (cfg.claudeAdapter) executable;
  };

  codexAdapter = mkAdapter {
    pkg = cfg.codexAdapter.package;
    bin = "codex-acp";
    executableVar = "CODEX_PATH";
    inherit (cfg.codexAdapter) executable;
  };

  needsAgyPackage = cfg.agyAdapter.executable == null && defaultAgyExecutable == null;

  agyAdapter = import ./agy/package.nix {
    inherit pkgs lib agentsLib;
    inherit (config.agents) resolved;
    inherit (cfg.agyAdapter) package;
    inherit (config.agents) proxy;
  };

  # ------------------------------------------------------------------------------------------------
  # Client configuration
  # ------------------------------------------------------------------------------------------------
  agents =
    lib.optionalAttrs cfg.claudeAdapter.enable {
      claude.argv = [ (profileBin "claude-agent-acp") ];
    }
    // lib.optionalAttrs cfg.codexAdapter.enable {
      codex.argv = [ (profileBin "codex-acp") ];
    }
    // lib.optionalAttrs cfg.agyAdapter.enable {
      agy.argv = [
        (lib.defaultTo (profileBin "agy") cfg.agyAdapter.executable)
        "acp"
      ];
    };

  configFile = json.generate "acpx-config.json" {
    inherit agents;
    inherit (cfg) defaultAgent timeout;
  };
in
{
  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.acp = {
    enable = lib.mkEnableOption "Agent Client Protocol (acpx and agent adapters)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.acpx or selfPackages.acpx;
      defaultText = lib.literalExpression "pkgs.acpx or self.packages.\${system}.acpx";
      description = "Package providing the acpx CLI";
    };

    claudeAdapter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install and register the claude-agent-acp adapter";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = llmAgentsPackages.claude-agent-acp;
        description = "Package providing the claude-agent-acp binary";
      };

      executable = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = defaultClaudeExecutable;
        description = "Path exported as CLAUDE_CODE_EXECUTABLE for claude-agent-acp";
      };
    };

    codexAdapter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install and register the codex-acp adapter";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = llmAgentsPackages.codex-acp;
        description = "Package providing the codex-acp binary";
      };

      executable = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = defaultCodexExecutable;
        description = "Path exported as CODEX_PATH for codex-acp";
      };
    };

    agyAdapter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.agents.agy.enable or false;
        defaultText = lib.literalExpression "config.agents.agy.enable or false";
        description = "Register the Antigravity CLI ACP server";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = llmAgentsPackages.antigravity-cli;
        description = "Fallback package providing the agy binary";
      };

      executable = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = defaultAgyExecutable;
        description = "Path to an existing agy executable for the ACP server";
      };
    };

    defaultAgent = lib.mkOption {
      type = lib.types.str;
      default = "codex";
      description = "Default ACP agent name written to ~/.acpx/config.json";
    };

    timeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = "Seconds each prompt waits for a response before acpx exits with code 3";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home.packages = [
      acpxBin
    ]
    ++ lib.optional cfg.claudeAdapter.enable claudeAdapter
    ++ lib.optional cfg.codexAdapter.enable codexAdapter
    ++ lib.optional (cfg.agyAdapter.enable && needsAgyPackage) agyAdapter;

    home.file.".acpx/config.json".source = configFile;
  };
}
