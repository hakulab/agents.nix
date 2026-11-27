# ==================================================================================================
# Scrapling MCP Server Preset
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
  p = config.agents.mcp.presets.scrapling;
  inherit (config.agents.browser) chromiumPackage;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.mcp.presets.scrapling = {
    enable = lib.mkEnableOption "Scrapling MCP server preset";
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.mcp.servers = lib.mkIf p.enable {
    scrapling = {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.scrapling;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "uvx";
      command = lib.mkDefault (
        [
          "--from"
          "scrapling[ai]@latest"
          "scrapling-mcp"
        ]
        ++ lib.optional (chromiumPackage != null) "--executable-path=${lib.getExe chromiumPackage}"
      );
    };
  };
}
