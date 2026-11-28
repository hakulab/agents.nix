# ==================================================================================================
# Antigravity CLI Home Manager Module (agents.agy)
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

    auth = agentsLib.profiles.mkOptions { };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra settings recursively merged into the managed Antigravity CLI settings";
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

  options.agents.resolved.clientProfiles.agy = agentsLib.profiles.mkClientProfilesOption (
    import ./supported-profiles.nix {
      inherit config lib agentsLib;
    }
  );

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config =
    let
      enabledServers = resolved.mcp.computeEnabledServers cfg.mcp;

      permissionSettings = import ./permissions.nix {
        inherit
          config
          lib
          agentsLib
          enabledServers
          ;
      };

      profiles = import ./profiles.nix {
        inherit
          config
          pkgs
          lib
          agentsLib
          repoRoot
          permissionSettings
          ;
      };

      agents = import ./agents.nix {
        inherit lib resolved;
        inherit (cfg.agents) enabledAgents;
      };

      mcp = import ./mcp.nix {
        inherit lib resolved enabledServers;
      };

      agyPackage = import ./package.nix {
        inherit pkgs lib agentsLib;
        inherit (config.agents) resolved proxy;
        inherit (cfg) package;
        profileWrapArgs = profiles.wrapArgs;
      };
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        profiles.config

        {
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
        }
      ]
    );
}
