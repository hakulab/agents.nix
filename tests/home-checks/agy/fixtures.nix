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
    set -euo pipefail

    if [[ -z "''${GEMINI_API_KEY-}" ]]; then
      key_status=""
    elif [[ "''${GEMINI_API_KEY-}" == "fixture-key" ]]; then
      key_status="fixture-key"
    else
      key_status="unexpected-key"
    fi

    printf '%s\n' \
      "''${HTTPS_PROXY-}" \
      "''${NO_PROXY-}" \
      "$key_status" \
      "''${GOOGLE_GEMINI_BASE_URL-}" \
      "''${AGY_ADC_AUTH-}" \
      "$@"
  '';

  stubGemini = pkgs.writeShellScriptBin "gemini-cli" "exit 0";

  agyPackages = cfg: lib.filter (pkg: lib.getName pkg == "agy") cfg.home.packages;
  evalAcpWith = modules: evalHomeWith ([ homeModules.acp ] ++ modules) { agents.acp.enable = true; };

  fixtureKey = "${pkgs.writeText "agy-fixture-key" "fixture-key\n"}";
  explicitExecutable = "/fixtures/local/bin/agy";

  # ------------------------------------------------------------------------------------------------
  # Managed CLI, customizations, auth profiles, proxy, and default ACP
  # ------------------------------------------------------------------------------------------------
  managedConfig = {
    agents = {
      agy = {
        enable = true;
        package = stubAgy;
        extraSettings.customSetting = "enabled";

        agents.enabledAgents = [
          "researcher"
          "reviewer"
        ];

        auth = {
          defaultProfile = "official";
          enabledProfiles = [
            "official"
            "ai-studio"
            "gateway"
            "official-token"
          ];
        };
      };

      instructions.extraSections = "Project guidance.";

      roles.definitions.researcher.agy = {
        mainAgent = true;
        inheritCustomizations = false;
        tools = [ "view_file" ];
      };

      skills.sources.sample.source = "/fixtures/sample-skill";

      models = {
        defaults = {
          gemini.default = "gemini-4-hydrogen";
          native-api = {
            default = "gemini-4-neon";
            standard = "gemini-4-neon";
            mini = "gemini-4-hydrogen";
            flagship = "gemini-4-neon";
          };
        };

        workloadPolicy.gemini.default = "medium";
        catalog.gemini-4-hydrogen.channelId.google = "gemini/gemini-4-hydrogen";
      };

      proxy = {
        enable = true;
        url = "https://proxy.example.test";
        noProxy = [ "direct.example.test" ];
      };

      mcp = {
        disabledServers = [ "hidden" ];
        servers = {
          local = {
            displayName = "Local";
            command = [ "example-mcp" ];
            envFiles.MCP_TOKEN = "/run/secrets/mcp-token";
            permissions = {
              allowTools = [ "read_item" ];
              gateTools = [
                {
                  tool = "write_item";
                  reason = "Writes data.";
                }
              ];
            };
          };

          remote = {
            displayName = "Remote";
            type = "http";
            url = "https://example.test/mcp";
          };

          hidden = {
            displayName = "Hidden";
            command = [ "example-mcp" ];
            permissions.allowTools = [ "read_item" ];
          };
        };
      };

      permissions.gateCommands = [
        {
          command = "example deploy";
          reason = "Deploys an application.";
        }
      ];

      providers = {
        studio = {
          apiKeyFile = "/fixtures/ignored-key";
          clientApiKeyFiles.agy = fixtureKey;
          apiUrls.gemini = "https://gemini.example.test";
        };

        gateway = {
          apiUrls.openai-responses = "https://gateway.example.test/v1";
          apiKeyFile = fixtureKey;
        };
      };

      profiles = {
        ai-studio = {
          provider = "studio";
          family = "gemini";
          defaultsKey = "native-api";
        };

        gateway = {
          provider = "gateway";
          family = "gemini";
        };

        official-token = {
          family = "gemini";
          oauthTokenFile = "/fixtures/oauth-token";
        };
      };
    };
  };

  managedCfg = evalAcpWith [
    homeModules.agy
    managedConfig
  ];

  # ------------------------------------------------------------------------------------------------
  # Switched profiles and error cases
  # ------------------------------------------------------------------------------------------------
  officialProfile =
    managedCfg.home.file."${managedCfg.xdg.stateHome}/agy/profiles/official.env.sh".source;

  officialState = pkgs.linkFarm "agy-active-official-profile" {
    "agy/active-profile" = officialProfile;
  };

  managedAuthCfg = evalAcpWith [
    homeModules.agy
    managedConfig
    {
      xdg.stateHome = builtins.unsafeDiscardStringContext "${officialState}";
    }
  ];

  apiProfile =
    managedCfg.home.file."${managedCfg.xdg.stateHome}/agy/profiles/ai-studio.env.sh".source;

  apiState = pkgs.linkFarm "agy-active-api-profile" { "agy/active-profile" = apiProfile; };

  apiAuthCfg = evalHomeWith [ homeModules.agy ] {
    xdg.stateHome = builtins.unsafeDiscardStringContext "${apiState}";
    agents.agy = {
      enable = true;
      package = stubAgy;
    };
  };

  missingKeyConfig = {
    agents = {
      agy = {
        enable = true;
        package = stubAgy;
        auth.defaultProfile = "ai-studio";
      };

      providers.studio = {
        apiKeyFile = "/fixtures/missing-key";
        apiUrls.gemini = "https://gemini.example.test";
      };

      profiles.ai-studio = {
        provider = "studio";
        family = "gemini";
      };
    };
  };

  missingKeyBaseCfg = evalHomeWith [ homeModules.agy ] missingKeyConfig;

  missingKeyProfile =
    missingKeyBaseCfg.home.file."${missingKeyBaseCfg.xdg.stateHome}/agy/profiles/ai-studio.env.sh".source;

  missingKeyState = pkgs.linkFarm "agy-active-missing-key-profile" {
    "agy/active-profile" = missingKeyProfile;
  };

  missingKeyCfg = evalHomeWith [ homeModules.agy ] (
    lib.recursiveUpdate missingKeyConfig {
      xdg.stateHome = builtins.unsafeDiscardStringContext "${missingKeyState}";
    }
  );

  extraHeadersCfg = evalHomeWith [ homeModules.agy ] {
    agents = {
      agy = {
        enable = true;
        package = stubAgy;
      };

      providers.studio = {
        apiKeyFile = fixtureKey;
        apiUrls.gemini = "https://gemini.example.test";
        extraHeaders."X-Test" = "1";
      };

      profiles.ai-studio = {
        provider = "studio";
        family = "gemini";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # ACP opt-out, fallback, and explicit executable
  # ------------------------------------------------------------------------------------------------
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

  explicitExecutableCfg = evalAcpWith [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = stubAgy;
        executable = explicitExecutable;
      };
    }
  ];

  nativeAgyAcpCfg = evalAcpWith [
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
    fixtureKey
    explicitExecutable
    managedCfg
    officialState
    managedAuthCfg
    apiState
    apiAuthCfg
    missingKeyState
    missingKeyCfg
    extraHeadersCfg
    optedOutCfg
    fallbackCfg
    explicitExecutableCfg
    nativeAgyAcpCfg
    ;
}
