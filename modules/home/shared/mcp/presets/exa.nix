# ==================================================================================================
# Exa MCP Server Preset
# ==================================================================================================

{
  agentsLib,
}:

{
  config,
  lib,
  ...
}:

let
  p = config.agents.mcp.presets.exa;
in
{
  options.agents.mcp.presets.exa = {
    enable = lib.mkEnableOption "Exa MCP server preset";

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file path containing the Exa API key";
    };

    enabledTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "web_search_exa"
        "web_fetch_exa"
        "web_search_advanced_exa"
        "agent_run"
      ];
      description = "Exa MCP tools enabled by default";
    };
  };

  config.agents.mcp.servers = lib.mkIf p.enable {
    exa = {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.exa;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "npx";
      command = lib.mkDefault [ "exa-mcp-server" ];
      envFiles = lib.optionalAttrs (p.apiKeyFile != null) {
        EXA_API_KEY = lib.mkDefault p.apiKeyFile;
      };
      envVars.ENABLED_TOOLS = lib.mkDefault (lib.concatStringsSep "," p.enabledTools);
    };
  };
}
