# ==================================================================================================
# Antigravity CLI Home Manager Module (agents.agy)
# ==================================================================================================

{
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
  cfg = config.agents.agy;
  inherit (config.agents) resolved;
in
{
  key = "agents-nix/home/agy";

  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.agy = {
    enable = lib.mkEnableOption "Antigravity CLI and Home Manager configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli;
      defaultText = lib.literalExpression "llm-agents.packages.\${system}.antigravity-cli";
      description = "Antigravity CLI package to install";
    };

    agents = {
      enabledAgents = resolved.agentRoleOptions.mkEnabledAgentsOption {
        description = "Custom agents to enable for Antigravity CLI";
      };
    };

    mcp = resolved.mcp.mkMcpOptions {
      default = resolved.mcp.serverNames;
      description = "Antigravity CLI MCP servers";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config =
    let
      agents = import ./agents.nix {
        inherit lib resolved;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ./mcp.nix {
        inherit lib resolved;
        enabledServers = resolved.mcp.computeEnabledServers cfg.mcp;
      };

      agyPackage = import ./package.nix {
        inherit
          pkgs
          lib
          agentsLib
          resolved
          ;
        inherit (cfg) package;
        inherit (config.agents) proxy;
      };
    in
    lib.mkIf cfg.enable {
      agents = {
        agy.mcp.disabledServers = resolved.mcp.disabledServers;
        skills.targets.agy = lib.mkDefault true;
      };

      programs.antigravity-cli = {
        enable = true;
        package = agyPackage;
        mcpServers = mcp.serversConfig;
        context.AGENTS = lib.mkIf (resolved.instructions != "") resolved.instructions;
      };

      home.file = agents.homeFiles;
    };
}
