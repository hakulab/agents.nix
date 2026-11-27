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
in
{
  options.agents.mcp.presets.scrapling = {
    enable = lib.mkEnableOption "Scrapling MCP server preset";

    chromiumPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = config.agents.browser.chromiumPackage;
      description = "Chromium executable package passed to scrapling-mcp";
    };
  };

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
        ++ lib.optional (p.chromiumPackage != null) "--executable-path=${lib.getExe p.chromiumPackage}"
      );
    };
  };
}
