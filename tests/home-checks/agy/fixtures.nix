# ==================================================================================================
# Antigravity CLI Home Manager Fixtures
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
}:

let
  inherit (harness) evalHomeWith;

  stubAgy = pkgs.writeShellScriptBin "agy" ''
    printf '%s\n' "$HTTPS_PROXY" "$NO_PROXY" "$@"
  '';

  stubGemini = pkgs.writeShellScriptBin "gemini-cli" "exit 0";

  agyPackages = cfg: lib.filter (pkg: lib.getName pkg == "agy") cfg.home.packages;

  # ------------------------------------------------------------------------------------------------
  # Shared customizations
  # ------------------------------------------------------------------------------------------------
  customizedCfg = evalHomeWith [ homeModules.agy ] {
    agents = {
      agy = {
        enable = true;
        agents.enabledAgents = [
          "researcher"
          "reviewer"
        ];
      };

      instructions = {
        enable = false;
        extraSections = "Project guidance.";
      };

      roles.definitions.researcher.agy = {
        mainAgent = true;
        inheritCustomizations = false;
        tools = [ "view_file" ];
      };

      skills.sources.sample.source = "/fixtures/sample-skill";

      mcp = {
        disabledServers = [ "hidden" ];
        servers = {
          local = {
            displayName = "Local";
            command = [ "example-mcp" ];
            envFiles.MCP_TOKEN = "/run/secrets/mcp-token";
          };

          remote = {
            displayName = "Remote";
            type = "http";
            url = "https://example.test/mcp";
          };

          hidden = {
            displayName = "Hidden";
            command = [ "example-mcp" ];
          };
        };
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # ACP configurations
  # ------------------------------------------------------------------------------------------------
  evalAcpWith = modules: evalHomeWith ([ homeModules.acp ] ++ modules) { agents.acp.enable = true; };

  combinedCfg = evalAcpWith [
    homeModules.agy
    {
      agents = {
        agy = {
          enable = true;
          package = stubAgy;
        };

        models = {
          defaults.gemini.default = "gemini-4-hydrogen";
          workloadPolicy.gemini.default = "medium";
          catalog.gemini-4-hydrogen.channelId.google = "gemini/gemini-4-hydrogen";
        };

        proxy = {
          enable = true;
          url = "https://proxy.example.test";
          noProxy = [ "direct.example.test" ];
        };
      };
    }
  ];

  optedOutCfg = evalAcpWith [
    homeModules.agy
    {
      agents.agy = {
        enable = true;
        package = stubAgy;
      };

      agents.acp.agyAdapter.enable = false;
    }
  ];

  fallbackCfg = evalAcpWith [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = stubAgy;
      };

      programs.antigravity-cli = {
        enable = true;
        package = stubGemini;
      };
    }
  ];

  explicitExecutable = "/fixtures/local/bin/agy";

  explicitExecutableCfg = evalAcpWith [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = stubAgy;
        executable = explicitExecutable;
      };
    }
  ];

  nullExecutableCfg = evalAcpWith [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = stubAgy;
        executable = null;
      };

      programs.antigravity-cli = {
        enable = true;
        package = stubAgy;
      };
    }
  ];
in
{
  inherit
    agyPackages
    stubAgy
    customizedCfg
    combinedCfg
    optedOutCfg
    fallbackCfg
    explicitExecutable
    explicitExecutableCfg
    nullExecutableCfg
    ;
}
