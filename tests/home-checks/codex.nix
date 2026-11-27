# ==================================================================================================
# Codex Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalModules,
  codexModule,
  sharedModule,
  homeDirectory,
}:

let
  evalCodex =
    extraModule:
    evalModules [
      codexModule
      extraModule
    ];

  # ------------------------------------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------------------------------------
  disabledCfg = evalCodex { };

  combinedCfg = evalModules [
    sharedModule
    codexModule
    {
      agents.codex.enable = true;
    }
  ];

  enabledCfg = evalCodex {
    agents.codex.enable = true;
  };

  sampleSkill = pkgs.runCommand "sample-codex-skill" { } ''
    mkdir -p "$out/scripts"
    echo "# Sample" > "$out/SKILL.md"
    echo "echo ok" > "$out/scripts/check.sh"
  '';

  fullCfg = evalCodex {
    home.preferXdgDirectories = true;

    agents = {
      models = {
        catalog = {
          "gpt-6.2-astra".channelId.openai = "openai/gpt-6.2-astra";
          "gpt-6.2-sol".channelId.openai = "openai/gpt-6.2-sol";
          "gpt-6-luna".channelId.openai = "openai/gpt-6-luna";

          "local-coder" = {
            name = "Local Coder";
            vendor = "local";
            apis = [ "openai-responses" ];
            contextWindow = 131072;
            maxTokens = 32768;
            autoCompactTokens = 96000;
            input = [ "text" ];
            reasoning = true;
            thinking = {
              mode = "effort";
              efforts = [
                "low"
                "medium"
                "high"
              ];
              defaultLevel = "medium";
            };
            channelId.local = "local/coder";
          };

          "local-writer" = {
            name = "Local Writer";
            vendor = "local";
            apis = [ "openai-responses" ];
            contextWindow = 131072;
            maxTokens = 32768;
            autoCompactTokens = 96000;
            input = [ "text" ];
            reasoning = true;
            thinking = {
              mode = "effort";
              efforts = [
                "low"
                "medium"
                "high"
              ];
              defaultLevel = "medium";
            };
            channelId.local = "local/writer";
          };
        };

        defaults.local = {
          default = "local-coder";
          flagship = "local-coder";
          standard = "local-coder";
          mini = "local-coder";
        };
      };

      providers.my-gateway = {
        baseUrl = "https://gw.example.test";
        apiUrls.openai-responses = "https://gw.example.test/openai/v1";
        apiKeyFile = "/run/secrets/gw-default";
        clientApiKeyFiles.codex = "/run/secrets/gw-codex";
        caCertFile = "/run/secrets/gw-ca.pem";
        extraHeaders."x-tenant" = "demo";
        extraEnv.CUSTOM_FLAG = "1";
        extraEnvFiles.CUSTOM_TOKEN = "/run/secrets/custom-token";
        channels = {
          openai = {
            family = "gpt";
            nativeWebSearch = false;
          };
          local = {
            family = "local";
            nativeWebSearch = false;
          };
        };
      };

      profiles = {
        gw-gpt = {
          provider = "my-gateway";
          family = "gpt";
          channel = "openai";
          clients = [ "codex" ];
        };

        gw-local = {
          provider = "my-gateway";
          family = "local";
          channel = "local";
          proseModel = "local-writer";
          clients = [ "codex" ];
        };

        claude-only = {
          provider = null;
          family = "claude";
          clients = [ "claude-code" ];
        };
      };

      modelCall = {
        enable = true;
        baseUrl = "https://gw.example.test";
        apiKeyFile = "/run/secrets/model-call";
      };

      mcp = {
        disabledServers = [ "blocked" ];
        presets.deepwiki.enable = true;
        servers = {
          customHttp = {
            type = "http";
            displayName = "CustomHttp";
            url = "https://mcp.example.test/mcp";
            permissions.allowTools = [ "list_items" ];
          };
          blocked = {
            type = "http";
            displayName = "Blocked";
            url = "https://blocked.example.test/mcp";
          };
        };
      };

      skills.sources.trusted = {
        source = sampleSkill;
        trustedScripts = [ "scripts/check.sh" ];
      };

      codex = {
        enable = true;
        rulesFileName = "custom.rules";
        auth.defaultProfile = "gw-gpt";

        hooks.extraEvents = {
          SessionStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = "echo session-started";
                }
              ];
            }
          ];

          Stop = [
            {
              hooks = [
                {
                  type = "command";
                  command = "workmux set-window-status done";
                }
              ];
            }
          ];
        };

        plugins = {
          "custom@example".enabled = true;
          "browser@openai-bundled".enabled = false;
        };

        desktop = {
          enable = true;
          settings.codeFontSize = 16;
        };

        extraSettings = {
          model_verbosity = "medium";
        };
      };
    };
  };

  invalidDefaultProfileCfg = evalCodex {
    agents.codex = {
      enable = true;
      auth.defaultProfile = "nonexistent";
    };
  };

  missingProviderBaseUrlCfg = evalCodex {
    agents = {
      providers.broken-gw = {
        apiKeyFile = "/run/secrets/key";
      };
      profiles.broken = {
        provider = "broken-gw";
        family = "gpt";
        clients = [ "codex" ];
      };
      codex.enable = true;
    };
  };

  missingMcpServerCfg = evalCodex {
    agents.codex = {
      enable = true;
      mcp.enabledServers = [ "does-not-exist" ];
    };
  };

  conflictingCaCertCfg = evalCodex {
    agents = {
      providers = {
        gw-a = {
          baseUrl = "https://gw-a.example.test";
          caCertFile = "/run/secrets/ca-a.pem";
        };
        gw-b = {
          baseUrl = "https://gw-b.example.test";
          caCertFile = "/run/secrets/ca-b.pem";
        };
      };
      profiles = {
        a = {
          provider = "gw-a";
          family = "gpt";
          clients = [ "codex" ];
        };
        b = {
          provider = "gw-b";
          family = "gpt";
          clients = [ "codex" ];
        };
      };
      codex.enable = true;
    };
  };

  noResearcherCfg = evalCodex {
    agents.codex = {
      enable = true;
      agents.enabledAgents = [ "implementer" ];
    };
  };

  renamedGptCfg = evalCodex {
    agents = {
      models.catalog."gpt-6.2-sol".channelId.renamed = "custom/renamed-gpt";
      providers.renamed-gw = {
        baseUrl = "https://renamed.example.test";
        channels.renamed = {
          family = "gpt";
          nativeWebSearch = false;
        };
      };
      profiles.renamed = {
        provider = "renamed-gw";
        family = "gpt";
        channel = "renamed";
        clients = [ "codex" ];
      };
      codex.enable = true;
    };
  };

  mkModelCatalog =
    cfg:
    import ../../modules/home/codex/models.nix {
      inherit pkgs lib;
      codexPackage = cfg.agents.codex.package;
    };

  fullResolvedProfiles = fullCfg.agents.resolved.resolveProfiles {
    nativeFamily = "gpt";
    client = "codex";
  };

  localCustomCatalog = mkModelCatalog fullCfg fullResolvedProfiles.gw-local;
  localCustomSlugs =
    map (model: model.slug)
      (builtins.fromJSON localCustomCatalog.modelMetadata).models;

  renamedResolvedProfiles = renamedGptCfg.agents.resolved.resolveProfiles {
    nativeFamily = "gpt";
    client = "codex";
  };

  renamedGptCatalog = mkModelCatalog renamedGptCfg renamedResolvedProfiles.renamed;

  enabledInternal = enabledCfg.agents.codex._internal;
  fullInternal = fullCfg.agents.codex._internal;
  fullConfigDir = "${fullCfg.xdg.configHome}/codex";
in
check "home-codex" [
  # ------------------------------------------------------------------------------------------------
  # Default disabled state
  # ------------------------------------------------------------------------------------------------
  {
    name = "codex module is explicitly opt-in and inactive by default";
    ok =
      !disabledCfg.agents.codex.enable
      && !disabledCfg.programs.codex.enable
      && !(disabledCfg.home.file ? codexRules)
      && !(disabledCfg.home.activation ? codexMutableConfig)
      && !(disabledCfg.home.activation ? codexDaemon)
      && !disabledCfg.agents.skills.targets.codex
      && lib.all (a: a.assertion) disabledCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Standalone and combined module imports
  # ------------------------------------------------------------------------------------------------
  {
    name = "importing both sharedModule and codexModule deduplicates shared options cleanly";
    ok =
      combinedCfg.agents.codex.enable
      && combinedCfg.programs.codex.enable
      && lib.all (a: a.assertion) combinedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Enabled defaults
  # ------------------------------------------------------------------------------------------------
  {
    name = "enabling codex configures programs.codex, wrapped package, and shared instructions";
    ok =
      enabledCfg.programs.codex.enable
      && lib.isDerivation enabledCfg.agents.codex.package
      && lib.hasPrefix "codex-" enabledCfg.programs.codex.package.name
      && enabledCfg.programs.codex.context == enabledCfg.agents.resolved.instructions
      && enabledCfg.agents.skills.targets.codex;
  }
  {
    name = "default rules file uses rules/agents-nix.rules with gate and read-only allow rules";
    ok =
      enabledCfg.home.file.codexRules.target == ".codex/rules/agents-nix.rules"
      && lib.hasInfix ''decision = "prompt"'' enabledCfg.home.file.codexRules.text
      && lib.hasInfix ''decision = "allow"'' enabledCfg.home.file.codexRules.text;
  }
  {
    name = "notify wires project-notify with --app codex";
    ok =
      builtins.length enabledInternal.settings.notify == 5
      && lib.hasSuffix "/bin/project-notify" (builtins.elemAt enabledInternal.settings.notify 0)
      && builtins.elemAt enabledInternal.settings.notify 1 == "--app"
      && builtins.elemAt enabledInternal.settings.notify 2 == "codex"
      && builtins.elemAt enabledInternal.settings.notify 3 == "Codex";
  }
  {
    name = "default hooks install compactContext and autoFormat without commentGate when modelCall is disabled";
    ok =
      enabledCfg.xdg.dataFile ? "agents-nix/hooks/codex-compact-context"
      && enabledCfg.xdg.dataFile ? "agents-nix/hooks/codex-auto-format"
      && !(enabledCfg.xdg.dataFile ? "agents-nix/hooks/codex-comment-gate")
      && enabledInternal.settings.hooks ? SessionStart
      && enabledInternal.settings.hooks ? PostToolUse;
  }
  {
    name = "official profile configures default models, roles, explorer override, and profile switcher";
    ok =
      enabledInternal.profiles ? official
      && enabledInternal.profiles.official.model_provider == "openai"
      && enabledInternal.profiles.official.web_search == "live"
      && enabledInternal.profiles.official.agents ? researcher
      && enabledInternal.profiles.official.agents ? explorer
      &&
        enabledInternal.profiles.official.agents.explorer
        == enabledInternal.profiles.official.agents.researcher
      && enabledCfg.home.file ? "${enabledInternal.stateDir}/profiles/official.config.toml"
      && lib.any (pkg: pkg.name == "codex-switch") enabledCfg.home.packages;
  }
  {
    name = "activation registers mutable config, auth profile init, and stale daemon stop";
    ok =
      enabledCfg.home.activation ? codexMutableConfig
      && enabledCfg.home.activation ? codexAuthProfile
      && enabledCfg.home.activation ? codexDaemon
      && lib.all (a: a.assertion) enabledCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Custom providers, profiles, and runtime environment
  # ------------------------------------------------------------------------------------------------
  {
    name = "custom providers generate model_providers, per-client auth, CA cert, and extra env";
    ok =
      fullInternal.settings.model_providers ? my-gateway
      && fullInternal.settings.model_providers.my-gateway.base_url == "https://gw.example.test/openai/v1"
      && fullInternal.settings.model_providers.my-gateway.wire_api == "responses"
      && fullInternal.settings.model_providers.my-gateway.http_headers."x-tenant" == "demo"
      && fullInternal.settings.model_providers.my-gateway.auth.args == [ "/run/secrets/gw-codex" ]
      && fullInternal.envVars.CODEX_CA_CERTIFICATE == "/run/secrets/gw-ca.pem"
      && fullInternal.envVars.CUSTOM_FLAG == "1"
      && fullInternal.envFiles.CUSTOM_TOKEN == "/run/secrets/custom-token";
  }
  {
    name = "custom gpt and non-gpt profiles emit model catalogs while excluding other-client profiles";
    ok =
      fullInternal.profiles ? official
      && fullInternal.profiles ? gw-gpt
      && fullInternal.profiles ? gw-local
      && !(fullInternal.profiles ? claude-only)
      && fullInternal.profiles.gw-gpt.model == "openai/gpt-6.2-sol"
      && fullInternal.profiles.gw-gpt ? model_catalog_json
      && fullInternal.profiles.gw-gpt ? model_auto_compact_token_limit
      && fullInternal.profiles.gw-local.model == "local/coder"
      && fullInternal.profiles.gw-local ? model_catalog_json
      && !(fullInternal.profiles.gw-local ? model_auto_compact_token_limit);
  }

  # ------------------------------------------------------------------------------------------------
  # MCP servers, hooks, skills, and platform settings
  # ------------------------------------------------------------------------------------------------
  {
    name = "MCP servers propagate global disabledServers and attach tool approval modes";
    ok =
      fullInternal.settings.mcp_servers ? DeepWiki
      && fullInternal.settings.mcp_servers ? CustomHttp
      && !(fullInternal.settings.mcp_servers ? Blocked)
      && fullInternal.settings.mcp_servers.DeepWiki.url == "https://mcp.deepwiki.com/mcp"
      && fullInternal.settings.mcp_servers.DeepWiki.startup_timeout_sec == 120
      && fullInternal.settings.mcp_servers.DeepWiki.tools.read_wiki_structure.approval_mode == "approve"
      && fullInternal.settings.mcp_servers.CustomHttp.tools.list_items.approval_mode == "approve";
  }
  {
    name = "enabled modelCall installs commentGate and hooks.extraEvents merges with built-in and new events";
    ok =
      fullCfg.xdg.dataFile ? "agents-nix/hooks/codex-comment-gate"
      && fullInternal.settings.hooks ? SessionStart
      && builtins.length fullInternal.settings.hooks.SessionStart == 2
      && fullInternal.settings.hooks ? Stop
      && builtins.length fullInternal.settings.hooks.Stop == 1;
  }
  {
    name = "custom rulesFileName, XDG configDir, trusted skill rules, plugins, desktop, and extraSettings apply";
    ok =
      fullCfg.home.file.codexRules.target == ".config/codex/rules/custom.rules"
      && lib.hasInfix "${fullConfigDir}/skills/trusted/scripts/check.sh" fullCfg.home.file.codexRules.text
      && fullInternal.settings.plugins."custom@example".enabled
      && !fullInternal.settings.plugins."browser@openai-bundled".enabled
      && fullInternal.settings.desktop.codeFontSize == 16
      && fullInternal.settings.desktop.projectlessWorkspaceRoot == "${homeDirectory}/Codex"
      && fullInternal.settings.features.chronicle
      && fullInternal.settings.model_verbosity == "medium"
      && lib.all (a: a.assertion) fullCfg.assertions;
  }
  {
    name = "Darwin plugin overrides merge with bundled defaults";
    ok =
      !pkgs.stdenv.isDarwin
      || (
        fullInternal.settings.plugins."custom@example".enabled
        && !fullInternal.settings.plugins."browser@openai-bundled".enabled
        && fullInternal.settings.plugins."chrome@openai-bundled".enabled
      );
  }
  {
    name = "slugPrefix falls back to empty when default modelId does not end with modelKey";
    ok =
      lib.hasInfix "--arg prefix ''" renamedGptCatalog.buildCommand
      && !(lib.hasInfix "--arg prefix 'custom/renamed-gpt'" renamedGptCatalog.buildCommand);
  }
  {
    name = "custom model catalog includes distinct prose workload model";
    ok = lib.elem "local/coder" localCustomSlugs && lib.elem "local/writer" localCustomSlugs;
  }
  {
    name = "explorer override is omitted when researcher agent is disabled";
    ok =
      noResearcherCfg.agents.codex._internal.profiles.official.agents ? implementer
      && !(noResearcherCfg.agents.codex._internal.profiles.official.agents ? researcher)
      && !(noResearcherCfg.agents.codex._internal.profiles.official.agents ? explorer);
  }
  {
    name = "platform defaults enable desktop, plugins, and keybindings only on Darwin";
    ok =
      enabledCfg.agents.codex.desktop.enable == pkgs.stdenv.isDarwin
      && (enabledCfg.agents.codex.plugins != { }) == pkgs.stdenv.isDarwin
      && (enabledCfg.agents.codex.keybindings != [ ]) == pkgs.stdenv.isDarwin;
  }

  # ------------------------------------------------------------------------------------------------
  # Assertions and validation
  # ------------------------------------------------------------------------------------------------
  {
    name = "invalid auth.defaultProfile fails module assertions";
    ok = throws invalidDefaultProfileCfg.assertions;
  }
  {
    name = "referenced provider without baseUrl or openai-responses URL fails module assertions";
    ok = throws missingProviderBaseUrlCfg.assertions;
  }
  {
    name = "enabledServers referencing an unavailable MCP server fails module assertions";
    ok = throws missingMcpServerCfg.assertions;
  }
  {
    name = "multiple distinct provider caCertFile values fail module assertions";
    ok = throws conflictingCaCertCfg.assertions;
  }
]
