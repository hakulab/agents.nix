# ==================================================================================================
# MCP Presets, Custom Servers, and Permissions Evaluation Checks
# ==================================================================================================

{
  lib,
  harness,
}:

let
  inherit (harness) check throws evalHome;

  cfg = evalHome {
    agents = {
      browser.chromiumPackage = null;

      mcp = {
        uv.isolatedConfig = true;
        disabledServers = [ "exa" ];

        presets = {
          atlassian = {
            enable = true;
            url = "https://wiki.example.test";
            tokenFile = "/run/secrets/wiki-pat";
            clearProxy = true;
          };

          chromeDevtools = {
            enable = true;
            headless = true;
          };

          deepwiki.enable = true;

          exa = {
            enable = true;
            apiKeyFile = "/run/secrets/exa-key";
          };

          github = {
            enable = true;
            fallbackTokenFile = "/run/secrets/github-pat";
          };

          gitlab = {
            enable = true;
            fallbackTokenFile = "/run/secrets/gitlab-pat";
            fallbackApiUrl = "https://gitlab.example.test/api/v4";
          };

          scrapling.enable = true;
        };

        servers = {
          customHttp = {
            type = "http";
            displayName = "CustomHttp";
            url = "https://mcp.example.test/mcp";
            permissions.allowTools = [ "list_items" ];
          };

          disabledServer = {
            enable = false;
            type = "http";
            displayName = "DisabledServer";
            url = "https://disabled.example.test/mcp";
          };
        };
      };

      permissions.mcpAllows.disabledServer = [ "ping" ];
    };
  };

  isolatedUvCfg = evalHome {
    agents.mcp = {
      uv.isolatedConfig = true;
      presets.atlassian.enable = true;
    };
  };

  noIsolatedUvCfg = evalHome {
    agents.mcp = {
      uv.isolatedConfig = false;
      presets.atlassian.enable = true;
    };
  };

  invalidHttpCfg = evalHome {
    agents.mcp.servers.brokenHttp = {
      type = "http";
      url = null;
    };
  };

  mcp = cfg.agents.resolved.mcp;
  permissions = cfg.agents.resolved.permissions;

  computedEnabled = mcp.computeEnabledServers {
    enabledServers = mcp.serverNames;
    inherit (mcp) disabledServers;
  };
in
check "home-shared-mcp" [
  # ------------------------------------------------------------------------------------------------
  # Presets and custom server resolution
  # ------------------------------------------------------------------------------------------------
  {
    name = "enabled presets and custom servers appear in resolved.mcp.servers";
    ok =
      mcp.servers ? github
      && mcp.servers ? gitlab
      && mcp.servers ? exa
      && mcp.servers ? chromeDevtools
      && mcp.servers ? deepwiki
      && mcp.servers ? scrapling
      && mcp.servers ? atlassian
      && mcp.servers ? customHttp
      && !(mcp.servers ? disabledServer);
  }
  {
    name = "stdio servers resolve to wrapper binaries and http servers keep their URL";
    ok =
      mcp.servers.github.type == "stdio"
      && lib.hasSuffix "/bin/github-mcp" mcp.servers.github.command
      && mcp.servers.deepwiki.type == "http"
      && mcp.servers.deepwiki.url == "https://mcp.deepwiki.com/mcp"
      && mcp.servers.customHttp.type == "http"
      && mcp.servers.customHttp.url == "https://mcp.example.test/mcp";
  }
  {
    name = "uv.isolatedConfig controls --no-config in uvx wrappers";
    ok =
      isolatedUvCfg.agents.mcp.uv.isolatedConfig
      && !noIsolatedUvCfg.agents.mcp.uv.isolatedConfig
      &&
        isolatedUvCfg.agents.resolved.mcp.servers.atlassian.command
        != noIsolatedUvCfg.agents.resolved.mcp.servers.atlassian.command;
  }

  # ------------------------------------------------------------------------------------------------
  # Global blocklist and helper interface
  # ------------------------------------------------------------------------------------------------
  {
    name = "computeEnabledServers removes globally disabled servers";
    ok = !(lib.elem "exa" computedEnabled) && lib.elem "github" computedEnabled;
  }
  {
    name = "resolved.mcp exposes timeouts and displayNames";
    ok =
      mcp.timeouts.startup == 120
      && mcp.displayNames.github == "GitHub"
      && mcp.displayNames.customHttp == "CustomHttp";
  }

  # ------------------------------------------------------------------------------------------------
  # Server-declared permissions and validation
  # ------------------------------------------------------------------------------------------------
  {
    name = "custom server allowTools fold into resolved.permissions.mcpAllows and disabled servers remain valid";
    ok =
      lib.any (
        entry:
        entry.server == "customHttp" && entry.displayName == "CustomHttp" && entry.tool == "list_items"
      ) permissions.mcpAllows
      && lib.any (
        entry:
        entry.server == "disabledServer" && entry.displayName == "DisabledServer" && entry.tool == "ping"
      ) permissions.mcpAllows;
  }
  {
    name = "valid MCP configuration passes all module assertions";
    ok = lib.all (a: a.assertion) cfg.assertions;
  }
  {
    name = "HTTP server without url triggers assertion failure";
    ok = throws invalidHttpCfg.assertions;
  }
]
