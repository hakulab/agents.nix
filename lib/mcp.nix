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
      description,
      names ? null,
      default ? if names != null then names else [ ],
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
        description = "${description} to enable";
        inherit names default;
      };

      disabledServers = mkDisabledServersOption {
        description = "${description} to disable";
      };
    };

  computeEnabledServers = cfg: lib.subtractLists cfg.disabledServers cfg.enabledServers;
in
{
  inherit
    computeEnabledServers
    mkDisabledServersOption
    mkEnabledServersOption
    mkMcpOptions
    presetDisplayNames
    presetServerNames
    ;
}
