# ==================================================================================================
# Chrome DevTools MCP Server Preset
# ==================================================================================================

{
  agentsLib,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  p = config.agents.mcp.presets.chromeDevtools;
in
{
  options.agents.mcp.presets.chromeDevtools = {
    enable = lib.mkEnableOption "Chrome DevTools MCP server preset";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = !pkgs.stdenv.isDarwin;
      description = "Launch Chromium in headless mode";
    };

    chromiumPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = config.agents.browser.chromiumPackage;
      description = "Chromium executable package passed to chrome-devtools-mcp";
    };
  };

  config.agents.mcp.servers = lib.mkIf p.enable {
    chromeDevtools = {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.chromeDevtools;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "npx";
      command = lib.mkDefault (
        [ "chrome-devtools-mcp" ]
        ++ lib.optional (p.chromiumPackage != null) "--executable-path=${lib.getExe p.chromiumPackage}"
        ++ [ "--isolated" ]
        ++ lib.optional p.headless "--headless"
      );
    };
  };
}
