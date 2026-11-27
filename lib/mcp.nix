# ==================================================================================================
# MCP Server Options
# ==================================================================================================

{
  lib,
}:

let
  presetDisplayNames = {
    atlassian = "Atlassian";
    chromeDevtools = "ChromeDevTools";
    deepwiki = "DeepWiki";
    exa = "Exa";
    github = "GitHub";
    gitlab = "GitLab";
    scrapling = "Scrapling";
  };

  presetServerNames = builtins.attrNames presetDisplayNames;

  mkEnabledServersOption =
    {
      names ? null,
      default ? if names != null then names else [ ],
      description,
    }:
    lib.mkOption {
      type = lib.types.listOf (if names != null then lib.types.enum names else lib.types.str);
      inherit default description;
    };

  mkDisabledServersOption =
    { description }:
    lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      inherit description;
    };

  mkMcpOptions =
    {
      names ? null,
      default ? if names != null then names else [ ],
      description ? "MCP servers",
    }:
    {
      enabledServers = mkEnabledServersOption {
        inherit names default;
        description = "${description} to enable";
      };

      disabledServers = mkDisabledServersOption {
        description = "${description} to disable";
      };
    };

  computeEnabledServers = cfg: lib.subtractLists cfg.disabledServers cfg.enabledServers;
in
{
  inherit
    presetDisplayNames
    presetServerNames
    mkEnabledServersOption
    mkDisabledServersOption
    mkMcpOptions
    computeEnabledServers
    ;
}
