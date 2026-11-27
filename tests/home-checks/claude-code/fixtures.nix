# ==================================================================================================
# Claude Code Home Manager Fixtures
# ==================================================================================================

{
  pkgs,
  harness,
  homeModules,
}:

let
  inherit (harness) evalHomeWith;

  stubClaude = pkgs.writeShellScriptBin "claude" ''
    exit 0
  '';

  stubWorkmux = pkgs.writeShellScriptBin "workmux" ''
    exit 0
  '';

  stubStatusline = pkgs.writeShellScriptBin "claude-statusline" ''
    exit 0
  '';

  sampleSkill = pkgs.runCommand "sample-claude-skill" { } ''
    mkdir -p "$out/scripts"
    echo "# Sample" > "$out/SKILL.md"
    echo "echo ok" > "$out/scripts/check.sh"
  '';

  # ------------------------------------------------------------------------------------------------
  # Enabled and disabled configurations
  # ------------------------------------------------------------------------------------------------
  disabledCfg = evalHomeWith [ homeModules.claude-code ] { };

  standaloneEnabledCfg = evalHomeWith [ homeModules.claude-code ] {
    agents.claude-code.enable = true;
  };

  combinedEnabledCfg =
    evalHomeWith
      [
        homeModules.shared
        homeModules.claude-code
      ]
      {
        agents.claude-code = {
          enable = true;
          package = stubClaude;
          hooks.worktree.workmuxPackage = stubWorkmux;
          statusline.package = stubStatusline;
        };
      };

  fullCfg =
    evalHomeWith
      [
        homeModules.shared
        homeModules.claude-code
      ]
      {
        agents = {
          browser.chromiumPackage = null;

          permissions = {
            ownRepositories = [ "github.com/example-org" ];
            allowPolicies = [ "Custom allow policy for tests." ];
          };

          models.catalog = {
            claude-opus-5-5.channelId = {
              anthropic = "gw/claude-opus-5-5";
              alt = "alt/claude-opus-5-5";
            };
            claude-sonnet-5-5.channelId = {
              anthropic = "gw/claude-sonnet-5-5";
              alt = "alt/claude-sonnet-5-5";
            };
            claude-haiku-5-5.channelId = {
              anthropic = "gw/claude-haiku-5-5";
              alt = "alt/claude-haiku-5-5";
            };
            gemini-4-neon.channelId.google = "google/gemini-4-neon";
          };

          providers.example-gateway = {
            baseUrl = "https://gw.example.test";
            apiUrls.anthropic-messages = "https://gw.example.test/anthropic";
            apiKeyFile = "/run/secrets/gw-key";
            clientApiKeyFiles.claude-code = "/run/secrets/gw-claude-key";
            caCertFile = "/run/secrets/gw-ca.pem";
            extraHeaders.x-tenant = "demo";
            extraEnv.CUSTOM_PROVIDER_FLAG = "1";
            extraEnvFiles.EXTRA_PROVIDER_SECRET = "/run/secrets/extra-secret";
            channels = {
              anthropic = {
                family = "claude";
                nativeWebSearch = false;
              };
              alt = {
                family = "claude";
                nativeWebSearch = false;
              };
              google = {
                family = "gemini";
                nativeWebSearch = false;
              };
            };
          };

          profiles = {
            gw-claude = {
              provider = "example-gateway";
              family = "claude";
              channel = "anthropic";
              clients = [ "claude-code" ];
            };

            gw-alt = {
              provider = "example-gateway";
              family = "claude";
              channel = "alt";
              clients = [ "claude-code" ];
            };

            official-token = {
              provider = null;
              family = "claude";
              oauthTokenFile = "/run/secrets/claude-oauth";
              clients = [ "claude-code" ];
            };
          };

          modelCall = {
            enable = true;
            baseUrl = "https://gw.example.test";
            apiKeyFile = "/run/secrets/model-call-key";
          };

          mcp = {
            disabledServers = [ "deepwiki" ];
            presets = {
              deepwiki.enable = true;
              github.enable = true;
            };
            servers.customHttp = {
              type = "http";
              displayName = "CustomHttp";
              url = "https://mcp.example.test/mcp";
            };
          };

          skills.sources.trusted-skill = {
            source = sampleSkill;
            trustedScripts = [ "scripts/check.sh" ];
          };

          claude-code = {
            enable = true;
            package = stubClaude;

            agents.enabledAgents = [
              "architect"
              "reviewer"
            ];

            auth.profileOverrides.gw-claude = {
              extraEnv.OVERRIDE_FLAG = "yes";
              extraHeaders.x-override = "1";
              sessionEffort = "high";
              modelEfforts.claude-opus-5-5 = "max";
              compactWindows.claude-opus-5-5 = 250000;
              modelOverrides.claude-haiku-5-5 = "custom/claude-haiku-5-5";
            };

            hooks.worktree.workmuxPackage = stubWorkmux;

            plugins = {
              lspPlugins = true;
              marketplaces.custom-mkt = "example/custom-mkt";
              enabled."custom-plugin@custom-mkt" = true;
            };

            statusline = {
              package = stubStatusline;
              models.custom-model = "Custom Model";
              costSources = [
                {
                  id = "demo-cost";
                  source.type = "http";
                }
              ];
              extraSettings = {
                refresh_interval = 30;
                models.extra-model = "Extra Model";
              };
            };

            extraInstructions = "## Local Notes\n\nFollow repository conventions.";
            extraSettings = {
              theme = "light";
              env.CUSTOM_CLAUDE_ENV = "yes";
            };
          };
        };
      };

  minimalHooksAndNoStatuslineCfg = evalHomeWith [ homeModules.claude-code ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks = {
        autoDream.enable = false;
        autoFormat.enable = false;
        commentGate.enable = false;
        completeness.enable = false;
        notify.enable = false;
        teammateIdle.enable = false;
        worktree = {
          enable = false;
          workmuxPackage = stubWorkmux;
        };
      };

      statusline = {
        enable = false;
        package = stubStatusline;
      };
    };
  };

  edgeCasesCfg =
    evalHomeWith
      [
        homeModules.shared
        homeModules.claude-code
      ]
      {
        agents = {
          mcp = {
            disabledServers = [ "deepwiki" ];
            presets = {
              deepwiki.enable = true;
              github.enable = true;
              gitlab.enable = true;
            };
          };

          profiles = {
            filtered-out = {
              provider = null;
              family = "claude";
              clients = [ "claude-code" ];
            };

            custom = {
              provider = null;
              family = "claude";
              clients = [ "claude-code" ];
            };
          };

          claude-code = {
            enable = true;
            package = stubClaude;
            hooks.worktree.workmuxPackage = stubWorkmux;
            statusline.package = stubStatusline;
            mcp.disabledServers = [ "gitlab" ];
            auth = {
              defaultProfile = "custom";
              enabledProfiles = [ "custom" ];
              profileOverrides.custom = {
                sessionEffort = "low";
                nativeWebSearch = false;
              };
            };
          };
        };
      };

  # ------------------------------------------------------------------------------------------------
  # Negative assertion fixtures
  # ------------------------------------------------------------------------------------------------
  missingBaseUrlProfileCfg = evalHomeWith [ homeModules.claude-code ] {
    agents = {
      providers.broken-api = {
        apiKeyFile = "/run/secrets/token";
      };

      profiles.broken-api = {
        provider = "broken-api";
        family = "claude";
        clients = [ "claude-code" ];
      };

      claude-code = {
        enable = true;
        package = stubClaude;
        hooks.worktree.workmuxPackage = stubWorkmux;
        statusline.package = stubStatusline;
      };
    };
  };

  unknownOverrideProfileCfg = evalHomeWith [ homeModules.claude-code ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profileOverrides.nonexistent.sessionEffort = "low";
    };
  };

  disabledOverrideProfileCfg = evalHomeWith [ homeModules.claude-code ] {
    agents = {
      profiles = {
        filtered-out = {
          provider = null;
          family = "claude";
          clients = [ "claude-code" ];
        };

        custom = {
          provider = null;
          family = "claude";
          clients = [ "claude-code" ];
        };
      };

      claude-code = {
        enable = true;
        package = stubClaude;
        hooks.worktree.workmuxPackage = stubWorkmux;
        statusline.package = stubStatusline;
        auth = {
          defaultProfile = "custom";
          enabledProfiles = [ "custom" ];
          profileOverrides.filtered-out.sessionEffort = "low";
        };
      };
    };
  };

  invalidEnvNameProfileCfg = evalHomeWith [ homeModules.claude-code ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profileOverrides.official.extraEnv."1INVALID" = "nope";
    };
  };

  unknownMcpCfg = evalHomeWith [ homeModules.claude-code ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      mcp.enabledServers = [ "nonexistent-server" ];
    };
  };
in
{
  inherit
    disabledCfg
    standaloneEnabledCfg
    combinedEnabledCfg
    fullCfg
    minimalHooksAndNoStatuslineCfg
    edgeCasesCfg
    missingBaseUrlProfileCfg
    unknownOverrideProfileCfg
    disabledOverrideProfileCfg
    invalidEnvNameProfileCfg
    unknownMcpCfg
    ;
}
