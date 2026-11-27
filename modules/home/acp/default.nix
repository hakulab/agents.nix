# ==================================================================================================
# Agent Client Protocol (ACP) Module (agents.acp)
# ==================================================================================================

{
  agentsLib,
  sharedModule,
  packagesFor,
  llmAgentsPackagesFor,
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
  selfPackages = packagesFor system;
  llmAgentsPackages = llmAgentsPackagesFor system;
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Default executable detection
  # ------------------------------------------------------------------------------------------------
  defaultClaudeExecutable =
    if
      (config.programs.claude-code.enable or false)
      && (config.programs.claude-code.package or null) != null
    then
      lib.getExe' config.programs.claude-code.package "claude"
    else
      null;

  defaultCodexExecutable =
    if (config.programs.codex.enable or false) && (config.programs.codex.package or null) != null then
      lib.getExe' config.programs.codex.package "codex"
    else
      null;

  # ------------------------------------------------------------------------------------------------
  # Package wrappers
  # ------------------------------------------------------------------------------------------------
  # acpx skips user settings by default, dropping Claude hooks, permissions, and instructions.
  acpxBin = agentsLib.wrapPackage {
    inherit pkgs;
    pkg = cfg.acpxPackage;
    name = "acpx-${cfg.acpxPackage.version}";
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
        name = "${bin}-${pkg.version}";
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

  # ------------------------------------------------------------------------------------------------
  # Client configuration
  # ------------------------------------------------------------------------------------------------
  # Session identity includes argv. Keep paths stable across rebuilds and upstream basenames intact
  # for adapter detection.
  profileBin = name: "${config.home.profileDirectory}/bin/${name}";

  agents =
    lib.optionalAttrs cfg.claudeAdapter.enable {
      claude.argv = [ (profileBin "claude-agent-acp") ];
    }
    // lib.optionalAttrs cfg.codexAdapter.enable {
      codex.argv = [ (profileBin "codex-acp") ];
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

    acpxPackage = lib.mkOption {
      type = lib.types.package;
      default = selfPackages.acpx;
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
    ++ lib.optional cfg.codexAdapter.enable codexAdapter;

    home.file.".acpx/config.json".source = configFile;
  };
}
