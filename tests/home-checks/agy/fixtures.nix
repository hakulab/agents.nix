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

  authStub = pkgs.writeShellScriptBin "agy" ''
    [ "${"$"}{GEMINI_API_KEY:-}" = fixture-key ] && echo key-loaded
    printf '%s\n' "${"$"}{GEMINI_API_KEY:+key-present}" "$GOOGLE_GEMINI_BASE_URL" "$@"
  '';

  stubGemini = pkgs.writeShellScriptBin "gemini-cli" "exit 0";

  agyPackages = cfg: lib.filter (pkg: lib.getName pkg == "agy") cfg.home.packages;

  # ------------------------------------------------------------------------------------------------
  # Auth profiles
  # ------------------------------------------------------------------------------------------------
  evalAuth =
    defaultProfile: apiKeyFile: extraConfig:
    evalHomeWith [ homeModules.agy ] {
      imports = [ extraConfig ];
      agents = {
        agy = {
          enable = true;
          package = authStub;
          auth = {
            inherit defaultProfile;
            enabledProfiles = [
              "official"
              "ai-studio"
              "gateway"
              "official-token"
            ];
          };
        };
        models.defaults.native-api = {
          default = "gemini-4-hydrogen";
          standard = "gemini-4-hydrogen";
          mini = "gemini-4-hydrogen";
          flagship = "gemini-4-neon";
        };
        providers = {
          studio = {
            apiKeyFile = "/fixtures/ignored-key";
            clientApiKeyFiles.agy = apiKeyFile;
            apiUrls.gemini = "https://gemini.example.test";
          };
          gateway = {
            apiUrls.openai-responses = "https://gateway.example.test/v1";
            inherit apiKeyFile;
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

  fixtureKey = "${pkgs.writeText "agy-fixture-key" "fixture-key\n"}";
  officialAuthCfg = evalAuth "official" fixtureKey { };
  apiProfile =
    officialAuthCfg.home.file."${officialAuthCfg.xdg.stateHome}/agy/profiles/ai-studio.sh".source;
  apiState = pkgs.linkFarm "agy-active-api-profile" { "agy/active-profile" = apiProfile; };
  apiAuthCfg = evalAuth "official" fixtureKey {
    xdg.stateHome = builtins.unsafeDiscardStringContext "${apiState}";
  };
  missingKeyCfg = evalAuth "ai-studio" "/fixtures/missing-key" { };

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
    officialAuthCfg
    apiAuthCfg
    apiState
    missingKeyCfg
    ;
}
