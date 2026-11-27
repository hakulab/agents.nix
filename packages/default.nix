# ==================================================================================================
# Custom Packages
# ==================================================================================================

{
  pkgs,
  dk,
  playwrightDriver,
}:

{
  acpx = pkgs.callPackage ./acpx { };
  browser-tools = pkgs.callPackage ./browser-tools {
    driver = playwrightDriver;
  };
  file-formatter = pkgs.callPackage ./file-formatter {
    inherit dk;
  };
  mcp-server-github = pkgs.callPackage ./mcp/mcp-server-github { };
  mcp-server-gitlab = pkgs.callPackage ./mcp/mcp-server-gitlab { };
}
