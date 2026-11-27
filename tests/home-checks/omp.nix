# ==================================================================================================
# OMP Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalHomeWith,
  sharedModule,
  ompModule,
}:

let
  stubOmp = pkgs.writeShellScriptBin "omp" ''
    exit 0
  '';

  stubChromium = pkgs.writeShellScriptBin "chromium" ''
    exit 0
  '';

  stubTelegram = pkgs.runCommand "stub-omp-telegram" { } ''
    mkdir -p "$out"
    touch "$out/index.ts"
  '';

  hasPackageNamed =
    name: packages: lib.any (pkg: (pkg.meta.mainProgram or pkg.name) == name) packages;

  findPackageNamed =
    name: packages: lib.findFirst (pkg: (pkg.meta.mainProgram or pkg.name) == name) null packages;

  disabledCfg = evalHomeWith [ ompModule ] { };

  defaultPkgCfg = evalHomeWith [ ompModule ] {
    agents.omp.enable = true;
  };

  basicCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;
      omp = {
        enable = true;
        package = stubOmp;
      };
    };
  };

  combinedCfg = evalHomeWith [ sharedModule ompModule ] {
    agents = {
      browser.chromiumPackage = stubChromium;

      models.catalog = {
        "claude-opus-5-5".channelId.anthropic = "gw/claude-opus-5-5";
        "claude-sonnet-5-5".channelId.anthropic = "gw/claude-sonnet-5-5";
        "claude-haiku-5-5".channelId.anthropic = "gw/claude-haiku-5-5";
        "gemini-4-neon".channelId.google = "google/gemini-4-neon";
      };

      providers.my-gateway = {
        baseUrl = "https://gw.example.test";
        apiUrls = {
          anthropic-messages = "https://gw.example.test/anthropic";
          openai-responses = "https://gw.example.test/openai";
        };
        apiKeyFile = "/run/secrets/gw-default";
        clientApiKeyFiles.omp = "/run/secrets/gw-omp";
        caCertFile = "/run/secrets/gw-ca.pem";
        extraHeaders."x-tenant" = "demo";
        channels = {
          anthropic = {
            family = "claude";
            nativeWebSearch = false;
          };
          google = {
            family = "gemini";
            nativeWebSearch = false;
          };
        };
      };

      profiles.work-claude = {
        provider = "my-gateway";
        family = "claude";
        channel = "anthropic";
        clients = [ "omp" ];
      };

      mcp = {
        disabledServers = [ "exa" ];
        presets = {
          deepwiki.enable = true;
          exa = {
            enable = true;
            apiKeyFile = "/run/secrets/exa-key";
          };
        };
      };

      omp = {
        enable = true;
        package = stubOmp;
        auth.defaultProfile = "work-claude";
        agents.enabledAgents = [ "reviewer" ];
        extensions = {
          fileFormatter.enable = false;
          telegram = {
            enable = true;
            package = stubTelegram;
            botTokenFile = "/run/secrets/telegram-bot";
          };
        };
        extraEnvFiles.EXA_API_KEY = "/run/secrets/exa-key";
        watchdogText = "Custom watchdog";
        extraSettings.theme.dark = "custom-dark";
      };
    };
  };

  filteredProfilesCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;

      providers.my-gateway = {
        baseUrl = "https://gw.example.test";
        apiKeyFile = "/run/secrets/gw-key";
      };

      profiles.gw-gpt = {
        provider = "my-gateway";
        family = "gpt";
      };

      omp = {
        enable = true;
        package = stubOmp;
        auth.profiles = [ "official" ];
      };
    };
  };

  invalidDefaultCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;
      omp = {
        enable = true;
        package = stubOmp;
        auth.defaultProfile = "missing-profile";
      };
    };
  };

  conflictingCaCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;

      providers = {
        gw-a = {
          baseUrl = "https://a.example.test";
          caCertFile = "/run/secrets/ca-a.pem";
        };
        gw-b = {
          baseUrl = "https://b.example.test";
          caCertFile = "/run/secrets/ca-b.pem";
        };
      };

      profiles = {
        prof-a = {
          provider = "gw-a";
          family = "gpt";
        };
        prof-b = {
          provider = "gw-b";
          family = "gpt";
        };
      };

      omp = {
        enable = true;
        package = stubOmp;
      };
    };
  };

  pathSecretCfg = evalHomeWith [ ompModule ] {
    agents.omp = {
      enable = true;
      package = stubOmp;
      extensions.telegram.botTokenFile = /tmp/not-a-string;
    };
  };

  longMcpToolCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;
      mcp.presets.github.enable = true;
      permissions.mcpGates.github = [
        {
          tool = "this_mcp_tool_name_is_intentionally_longer_than_sixty_four_characters";
          reason = "test";
        }
      ];
      omp = {
        enable = true;
        package = stubOmp;
      };
    };
  };

  missingBaseUrlCfg = evalHomeWith [ ompModule ] {
    agents = {
      browser.chromiumPackage = null;

      providers.no-url = { };

      profiles.gw-gpt = {
        provider = "no-url";
        family = "gpt";
      };

      omp = {
        enable = true;
        package = stubOmp;
      };
    };
  };

  stateDir = "${combinedCfg.xdg.stateHome}/omp";
  filteredStateDir = "${filteredProfilesCfg.xdg.stateHome}/omp";

  combinedOmpBin = findPackageNamed "omp" combinedCfg.home.packages;
  combinedMcp = builtins.fromJSON combinedCfg.home.file.".omp/agent/mcp.json".source.value;
  workClaudeProfile =
    builtins.fromJSON
      combinedCfg.home.file."${stateDir}/profiles/work-claude.config.yml".source.value;
  ompModelsActivation = combinedCfg.home.activation.ompModelsYaml.data;
in
check "home-omp" [
  # ------------------------------------------------------------------------------------------------
  # Opt-in and standalone import
  # ------------------------------------------------------------------------------------------------
  {
    name = "omp is disabled by default and installs no files or packages";
    ok =
      !disabledCfg.agents.omp.enable
      && !(disabledCfg.home.file ? ".omp/agent/AGENTS.md")
      && !(hasPackageNamed "omp-switch" disabledCfg.home.packages);
  }
  {
    name = "default omp package resolves to a derivation from llm-agents";
    ok = lib.isDerivation defaultPkgCfg.agents.omp.package;
  }
  {
    name = "standalone and combined imports pass all assertions";
    ok =
      lib.all (a: a.assertion) basicCfg.assertions && lib.all (a: a.assertion) combinedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Configuration files, agents, and extensions
  # ------------------------------------------------------------------------------------------------
  {
    name = "default omp config installs AGENTS.md, WATCHDOG.md, mcp.json, file-formatter, and roles";
    ok =
      basicCfg.home.file ? ".omp/agent/AGENTS.md"
      && basicCfg.home.file.".omp/agent/AGENTS.md".text == basicCfg.agents.resolved.instructions
      && basicCfg.home.file ? ".omp/agent/WATCHDOG.md"
      && basicCfg.home.file ? ".omp/agent/mcp.json"
      && basicCfg.home.file ? ".omp/agent/extensions/file-formatter.ts"
      && !(basicCfg.home.file ? ".omp/agent/extensions/omp-telegram")
      && basicCfg.home.file ? ".omp/agent/agents/reviewer.md"
      && lib.hasInfix "name: \"reviewer\"" basicCfg.home.file.".omp/agent/agents/reviewer.md".text
      && basicCfg.home.file ? ".omp/agent/agents/implementer.md"
      && basicCfg.agents.skills.targets.omp;
  }
  {
    name = "extension toggles, enabledAgents, and watchdogText customize generated files";
    ok =
      !(combinedCfg.home.file ? ".omp/agent/extensions/file-formatter.ts")
      && combinedCfg.home.file ? ".omp/agent/extensions/omp-telegram"
      && combinedCfg.home.file ? ".omp/agent/agents/reviewer.md"
      && !(combinedCfg.home.file ? ".omp/agent/agents/implementer.md")
      && combinedCfg.home.file.".omp/agent/WATCHDOG.md".text == "Custom watchdog";
  }

  # ------------------------------------------------------------------------------------------------
  # MCP integration and permissions
  # ------------------------------------------------------------------------------------------------
  {
    name = "global agents.mcp.disabledServers propagates to omp and filters generated mcp.json";
    ok =
      combinedCfg.agents.omp.mcp.disabledServers == [ "exa" ]
      && combinedMcp.mcpServers ? DeepWiki
      && combinedMcp.mcpServers.DeepWiki.type == "http"
      && combinedMcp.mcpServers.DeepWiki.url == "https://mcp.deepwiki.com/mcp"
      && combinedMcp.mcpServers.DeepWiki.timeout == 120000
      && !(combinedMcp.mcpServers ? Exa);
  }
  {
    name = "permissions guard throws on MCP tool names exceeding 64 characters";
    ok = throws (findPackageNamed "omp" longMcpToolCfg.home.packages).buildCommand;
  }

  # ------------------------------------------------------------------------------------------------
  # Auth profiles, wrapper, activations, and assertions
  # ------------------------------------------------------------------------------------------------
  {
    name = "enabled omp installs wrapped omp binary, omp-switch, profile files, and activation hooks";
    ok =
      combinedOmpBin != null
      && hasPackageNamed "omp-switch" combinedCfg.home.packages
      && combinedCfg.home.file ? "${stateDir}/profiles/official.config.yml"
      && combinedCfg.home.file ? "${stateDir}/profiles/work-claude.config.yml"
      && combinedCfg.home.activation ? ompModelsYaml
      && combinedCfg.home.activation ? ompAuthProfile;
  }
  {
    name = "generated profile YAML resolves model roles, aliases, and compaction thresholds";
    ok =
      workClaudeProfile.modelRoles.flagship == "my-gateway-anthropic/gw/claude-opus-5-5:high"
      && workClaudeProfile.modelRoles.prose == "my-gateway-google/google/gemini-4-neon:high"
      && workClaudeProfile.modelRoles.plan == "@flagship"
      && workClaudeProfile.compaction.enabled
      && workClaudeProfile.compaction.modelThresholds."my-gateway-anthropic/gw/claude-opus-5-5" == 400000;
  }
  {
    name = "omp wrapper injects CA cert, browser path, secret env files, and config flags";
    ok =
      lib.hasInfix "NODE_EXTRA_CA_CERTS" combinedOmpBin.buildCommand
      && lib.hasInfix "/run/secrets/gw-ca.pem" combinedOmpBin.buildCommand
      && lib.hasInfix "PUPPETEER_EXECUTABLE_PATH" combinedOmpBin.buildCommand
      && lib.hasInfix (builtins.unsafeDiscardStringContext (lib.getExe stubChromium)) combinedOmpBin.buildCommand
      && lib.hasInfix "TELEGRAM_BOT_TOKEN" combinedOmpBin.buildCommand
      && lib.hasInfix "/run/secrets/telegram-bot" combinedOmpBin.buildCommand
      && lib.hasInfix "EXA_API_KEY" combinedOmpBin.buildCommand
      && lib.hasInfix "/run/secrets/exa-key" combinedOmpBin.buildCommand
      && lib.hasInfix "omp-settings.yml" combinedOmpBin.buildCommand
      && lib.hasInfix "omp-permissions.yml" combinedOmpBin.buildCommand;
  }
  {
    name = "ompModelsYaml activation installs generated models.yml with shell-escaped target path";
    ok =
      lib.hasInfix "install -m0600" ompModelsActivation
      && lib.hasInfix (lib.escapeShellArg "${combinedCfg.home.homeDirectory}/.omp/agent/models.yml") ompModelsActivation;
  }
  {
    name = "auth.profiles allowlist filters installed profile files";
    ok =
      filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/official.config.yml"
      && !(filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/gw-gpt.config.yml");
  }
  {
    name = "invalid auth.defaultProfile fails module assertion";
    ok = throws invalidDefaultCfg.assertions;
  }
  {
    name = "multiple distinct provider caCertFile paths fail module assertion";
    ok = throws conflictingCaCfg.assertions;
  }
  {
    name = "provider without baseUrl or matching apiUrls throws when generating models.yml";
    ok = throws missingBaseUrlCfg.home.activation.ompModelsYaml.data;
  }
  {
    name = "secret *File options reject Nix path literals";
    ok = throws pathSecretCfg.agents.omp.extensions.telegram.botTokenFile;
  }
]
