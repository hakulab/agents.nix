# ==================================================================================================
# Antigravity CLI Home Manager Module (agents.agy)
# ==================================================================================================

{
  llm-agents,
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

  mcpServers = builtins.listToAttrs (
    map (
      name:
      lib.nameValuePair resolved.mcp.displayNames.${name} (
        removeAttrs resolved.mcp.servers.${name} [ "type" ]
      )
    ) (resolved.mcp.computeEnabledServers cfg.mcp)
  );

  models = {
    flagship = "pro";
    mini = "flash";
    prose = "pro";
  };

  renderAgent =
    name: role:
    let
      restrictions = lib.optionals (role.agy.tools != null) [
        "excludeDefaultComponents: true"
        "inheritMcp: false"
        "tools: ${builtins.toJSON role.agy.tools}"
      ];

      frontmatter = lib.concatStringsSep "\n" (
        [
          "---"
          "name: ${builtins.toJSON name}"
          "description: ${builtins.toJSON role.description}"
          "mainAgent: false"
          "model: ${models.${role.workload} or "inherit"}"
        ]
        ++ restrictions
        ++ [ "---" ]
      );
    in
    ''
      ${frontmatter}

      ${role.prompt}
    '';

  agentFiles = lib.genAttrs' cfg.agents.enabledAgents (
    name:
    lib.nameValuePair "${resolved.configDirs.agy}/agents/${name}.md" {
      text = renderAgent name resolved.agentRoles.${name};
    }
  );
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

    agents.enabledAgents = resolved.agentRoleOptions.mkEnabledAgentsOption {
      description = "Custom agents to enable for Antigravity CLI";
    };

    mcp = resolved.mcp.mkMcpOptions {
      default = resolved.mcp.serverNames;
      description = "Antigravity CLI MCP servers";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    agents = {
      agy.mcp.disabledServers = resolved.mcp.disabledServers;
      skills.targets.agy = lib.mkDefault true;
    };

    programs.antigravity-cli = {
      enable = true;
      inherit (cfg) package;
      inherit mcpServers;
      context.AGENTS = lib.mkIf (resolved.instructions != "") resolved.instructions;
    };

    home.file = agentFiles;
  };
}
