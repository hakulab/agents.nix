# ==================================================================================================
# DeepWiki MCP Server Preset
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
  p = config.agents.mcp.presets.deepwiki;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.mcp.presets.deepwiki = {
    enable = lib.mkEnableOption "DeepWiki HTTP MCP server preset";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://mcp.deepwiki.com/mcp";
      description = "DeepWiki MCP endpoint URL";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.mcp.servers = lib.mkIf p.enable {
    deepwiki = {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.deepwiki;
      type = lib.mkDefault "http";
      url = lib.mkDefault p.url;
    };
  };
}
