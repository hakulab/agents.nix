# ==================================================================================================
# Atlassian MCP Server Preset
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
  p = config.agents.mcp.presets.atlassian;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.mcp.presets.atlassian = {
    enable = lib.mkEnableOption "Atlassian MCP server preset";

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Confluence base URL exported as CONFLUENCE_URL";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file path containing the Confluence personal access token";
    };

    clearProxy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Clear HTTP(S) proxy environment variables before launching mcp-atlassian";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.mcp.servers = lib.mkIf p.enable {
    atlassian = {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.atlassian;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "uvx";
      command = lib.mkDefault [ "mcp-atlassian@latest" ];
      clearProxy = lib.mkDefault p.clearProxy;
      envFiles = lib.optionalAttrs (p.tokenFile != null) {
        CONFLUENCE_PERSONAL_TOKEN = lib.mkDefault p.tokenFile;
      };
      envVars = lib.optionalAttrs (p.url != null) {
        CONFLUENCE_URL = lib.mkDefault p.url;
      };
    };
  };
}
