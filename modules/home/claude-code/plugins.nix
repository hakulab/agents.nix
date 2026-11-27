# ==================================================================================================
# Claude Code Plugins
# ==================================================================================================

{
  lib,
  pluginsCfg,
}:

let
  lspEnabledPlugins = lib.optionalAttrs pluginsCfg.lspPlugins {
    "clangd-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "pyright-lsp@claude-plugins-official" = true;
    "rust-analyzer-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
  };

  enabledPlugins = lspEnabledPlugins // pluginsCfg.enabled;

  extraKnownMarketplaces = lib.mapAttrs (_: repo: {
    source = {
      source = "github";
      inherit repo;
    };
  }) pluginsCfg.marketplaces;
in
{
  inherit enabledPlugins extraKnownMarketplaces;
}
