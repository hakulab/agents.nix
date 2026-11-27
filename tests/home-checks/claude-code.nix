# ==================================================================================================
# Claude Code Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalHomeWith,
  sharedModule,
  claudeCodeModule,
  homeDirectory,
}:

let
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
  # Fixtures
  # ------------------------------------------------------------------------------------------------
  disabledCfg = evalHomeWith [ claudeCodeModule ] { };

  standaloneEnabledCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code.enable = true;
  };

  combinedEnabledCfg = evalHomeWith [ sharedModule claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
    };
  };

  fullCfg = evalHomeWith [ sharedModule claudeCodeModule ] {
    agents = {
      browser.chromiumPackage = null;

      permissions = {
        ownRepositories = [ "github.com/example-org" ];
        allowPolicies = [ "Custom allow policy for tests." ];
      };

      models.catalog = {
        "claude-opus-5-5".channelId = {
          anthropic = "gw/claude-opus-5-5";
          alt = "alt/claude-opus-5-5";
        };
        "claude-sonnet-5-5".channelId = {
          anthropic = "gw/claude-sonnet-5-5";
          alt = "alt/claude-sonnet-5-5";
        };
        "claude-haiku-5-5".channelId = {
          anthropic = "gw/claude-haiku-5-5";
          alt = "alt/claude-haiku-5-5";
        };
        "gemini-4-neon".channelId.google = "google/gemini-4-neon";
      };

      providers.example-gateway = {
        baseUrl = "https://gw.example.test";
        apiUrls.anthropic-messages = "https://gw.example.test/anthropic";
        apiKeyFile = "/run/secrets/gw-key";
        clientApiKeyFiles.claude-code = "/run/secrets/gw-claude-key";
        caCertFile = "/run/secrets/gw-ca.pem";
        extraHeaders."x-tenant" = "demo";
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

        hooks.worktree.workmuxPackage = stubWorkmux;

        plugins = {
          lspPlugins = true;
          marketplaces.custom-mkt = "example/custom-mkt";
          enabled."custom-plugin@custom-mkt" = true;
        };

        statusline = {
          package = stubStatusline;
          models."custom-model" = "Custom Model";
          costSources = [
            {
              id = "demo-cost";
              source.type = "http";
            }
          ];
          extraSettings.refresh_interval = 30;
        };

        extraInstructions = "## Local Notes\n\nFollow repository conventions.";
        extraSettings = {
          theme = "light";
          env.CUSTOM_CLAUDE_ENV = "yes";
        };
      };
    };
  };

  minimalHooksAndNoStatuslineCfg = evalHomeWith [ claudeCodeModule ] {
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

  edgeCasesCfg = evalHomeWith [ sharedModule claudeCodeModule ] {
    agents = {
      mcp = {
        disabledServers = [ "deepwiki" ];
        presets = {
          deepwiki.enable = true;
          github.enable = true;
          gitlab.enable = true;
        };
      };

      profiles.official = {
        family = "claude";
        clients = [ "codex" ];
      };

      claude-code = {
        enable = true;
        package = stubClaude;
        hooks.worktree.workmuxPackage = stubWorkmux;
        statusline.package = stubStatusline;
        mcp.disabledServers = [ "gitlab" ];
        auth = {
          defaultProfile = "custom";
          profiles.custom = {
            type = "subscription";
            sessionEffort = null;
            efforts = lib.mkForce { };
          };
        };
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Negative assertion fixtures
  # ------------------------------------------------------------------------------------------------
  missingBaseUrlProfileCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profiles.broken-api = {
        type = "api-key";
        tokenFile = "/run/secrets/token";
      };
    };
  };

  subscriptionWithTokenCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profiles.broken-sub = {
        type = "subscription";
        tokenFile = "/run/secrets/token";
      };
    };
  };

  invalidEnvNameProfileCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profiles.bad-env = {
        type = "subscription";
        extraEnv."1INVALID" = "nope";
      };
    };
  };

  pathSecretProfileCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      auth.profiles.bad-path = {
        type = "oauth-token";
        tokenFile = /tmp/not-a-string;
      };
    };
  };

  unknownMcpCfg = evalHomeWith [ claudeCodeModule ] {
    agents.claude-code = {
      enable = true;
      package = stubClaude;
      hooks.worktree.workmuxPackage = stubWorkmux;
      statusline.package = stubStatusline;
      mcp.enabledServers = [ "nonexistent-server" ];
    };
  };

  hasFailingAssertion = cfg: throws cfg.assertions;

  # ------------------------------------------------------------------------------------------------
  # Pure evaluation checks
  # ------------------------------------------------------------------------------------------------
  evalCheck = check "home-claude-code" [
    # ----------------------------------------------------------------------------------------------
    # Default disabled state
    # ----------------------------------------------------------------------------------------------
    {
      name = "disabled by default without enabling programs.claude-code or claude-statusline";
      ok =
        !disabledCfg.agents.claude-code.enable
        && !disabledCfg.programs.claude-code.enable
        && !disabledCfg.programs.claude-statusline.enable
        && !disabledCfg.agents.skills.targets.claude
        && !(disabledCfg.home.file ? ".claude/settings.json")
        && !(disabledCfg.home.file ? ".claude/CLAUDE.md")
        && lib.all (a: a.assertion) disabledCfg.assertions;
    }

    # ----------------------------------------------------------------------------------------------
    # Standalone and combined imports, packages, and instructions
    # ----------------------------------------------------------------------------------------------
    {
      name = "standalone import provides default upstream packages and enables claude-code";
      ok =
        standaloneEnabledCfg.programs.claude-code.enable
        && standaloneEnabledCfg.programs.claude-statusline.enable
        && standaloneEnabledCfg.agents.skills.targets.claude
        && lib.isDerivation standaloneEnabledCfg.agents.claude-code.package
        && lib.isDerivation standaloneEnabledCfg.agents.claude-code.hooks.worktree.workmuxPackage
        && lib.isDerivation standaloneEnabledCfg.agents.claude-code.statusline.package
        && lib.all (a: a.assertion) standaloneEnabledCfg.assertions;
    }
    {
      name = "importing sharedModule and claudeCodeModule together deduplicates cleanly";
      ok =
        combinedEnabledCfg.programs.claude-code.enable
        && combinedEnabledCfg.home.file ? ".claude/settings.json"
        && combinedEnabledCfg.home.file ? ".claude/CLAUDE.md"
        && combinedEnabledCfg.home.file ? ".claude/agents"
        && lib.all (a: a.assertion) combinedEnabledCfg.assertions;
    }
    {
      name = "CLAUDE.md includes shared instructions, Claude Code addendum, and extraInstructions";
      ok =
        let
          text = fullCfg.home.file.".claude/CLAUDE.md".text;
        in
        lib.hasInfix fullCfg.agents.resolved.instructions text
        && lib.hasInfix "## Claude Code" text
        && lib.hasInfix "## Local Notes" text;
    }

    # ----------------------------------------------------------------------------------------------
    # Hooks and data files
    # ----------------------------------------------------------------------------------------------
    {
      name = "default enabled hooks omit comment-gate when modelCall is disabled";
      ok =
        combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-dream"
        && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-format"
        && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-teammate-idle"
        && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-create"
        && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-remove"
        && !(combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-comment-gate");
    }
    {
      name = "enabled modelCall installs comment-gate hook alongside default hooks";
      ok = fullCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-comment-gate";
    }
    {
      name = "disabling all hooks installs no hook dataFiles";
      ok =
        !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-dream")
        && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-format")
        && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-teammate-idle")
        && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-create")
        && !minimalHooksAndNoStatuslineCfg.programs.claude-statusline.enable
        && lib.all (a: a.assertion) minimalHooksAndNoStatuslineCfg.assertions;
    }

    # ----------------------------------------------------------------------------------------------
    # Profiles, statusline, and platform paths
    # ----------------------------------------------------------------------------------------------
    {
      name = "profiles resolve official, gateway anthropic, gateway non-anthropic, and oauth-token";
      ok =
        let
          ps = fullCfg.agents.claude-code.auth.profiles;
        in
        ps ? official
        && ps ? gw-claude
        && ps ? gw-alt
        && ps ? official-token
        && ps.official.type == "subscription"
        && ps.gw-claude.type == "api-key"
        && ps.gw-claude.tokenFile == "/run/secrets/gw-claude-key"
        && ps.gw-claude.baseUrl == "https://gw.example.test/anthropic"
        && ps.gw-claude.modelOverrides."claude-opus-5-5" == "gw/claude-opus-5-5"
        && ps.gw-claude.agentModels.prose == "google/gemini-4-neon[1m]"
        && !(ps.gw-claude.extraEnv ? CLAUDE_CODE_AUTO_MODE_SERVER)
        && ps.gw-alt.extraEnv.CLAUDE_CODE_AUTO_MODE_SERVER == "0"
        && ps.gw-alt.extraEnv.CLAUDE_CODE_AUTO_MODE_MODEL == "alt/claude-haiku-5-5"
        && ps.official-token.type == "oauth-token"
        && ps.official-token.tokenFile == "/run/secrets/claude-oauth"
        && lib.all (a: a.assertion) fullCfg.assertions;
    }
    {
      name = "profile switcher package, activation entry, and stateDir follow platform homeDirectory";
      ok =
        lib.any (pkg: (pkg.name or "") == "claude-switch") fullCfg.home.packages
        && fullCfg.home.activation ? claudeCodeProfile
        && lib.hasPrefix "${homeDirectory}/" fullCfg.xdg.stateHome;
    }
    {
      name = "statusline populates catalog models, channelIds, custom models, costSources, and extraSettings";
      ok =
        let
          s = fullCfg.programs.claude-statusline.settings;
        in
        fullCfg.programs.claude-statusline.enable
        && s.models."claude-opus-5-5" == "Claude Opus 5.5"
        && s.models."gw/claude-opus-5-5" == "Claude Opus 5.5"
        && s.models."custom-model" == "Custom Model"
        && builtins.length s.cost_sources == 1
        && (builtins.head s.cost_sources).id == "demo-cost"
        && s.refresh_interval == 30;
    }

    {
      name = "custom plugin entries merge with built-in plugin and marketplace defaults";
      ok =
        let
          p = fullCfg.agents.claude-code.plugins;
        in
        p.marketplaces ? claude-plugins-official
        && p.marketplaces ? workmux
        && p.marketplaces ? custom-mkt
        && p.enabled."skill-creator@claude-plugins-official"
        && p.enabled."workmux-status@workmux"
        && p.enabled."custom-plugin@custom-mkt";
    }
    {
      name = "per-assistant disabledServers extends global disabledServers and absent official profile falls back cleanly";
      ok =
        lib.elem "deepwiki" edgeCasesCfg.agents.claude-code.mcp.disabledServers
        && lib.elem "gitlab" edgeCasesCfg.agents.claude-code.mcp.disabledServers
        && !(edgeCasesCfg.agents.claude-code.auth.profiles ? official)
        && edgeCasesCfg.agents.claude-code.auth.profiles.custom.sessionEffort == null
        && edgeCasesCfg.agents.claude-code.auth.profiles.custom.efforts == { }
        && lib.all (a: a.assertion) edgeCasesCfg.assertions;
    }

    # ----------------------------------------------------------------------------------------------
    # Validation and secret path constraints
    # ----------------------------------------------------------------------------------------------
    {
      name = "api-key profile without baseUrl fails assertion";
      ok = hasFailingAssertion missingBaseUrlProfileCfg;
    }
    {
      name = "subscription profile with tokenFile fails assertion";
      ok = hasFailingAssertion subscriptionWithTokenCfg;
    }
    {
      name = "non-POSIX extraEnv key fails assertion";
      ok = hasFailingAssertion invalidEnvNameProfileCfg;
    }
    {
      name = "Nix path literal on tokenFile is rejected to prevent store copying";
      ok = throws pathSecretProfileCfg.agents.claude-code.auth.profiles.bad-path.tokenFile;
    }
    {
      name = "unknown MCP server in enabledServers fails assertion";
      ok = hasFailingAssertion unknownMcpCfg;
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Rendered artifact checks (settings.json, wrapper, MCP config, profile bundle)
  # ------------------------------------------------------------------------------------------------
  fullSettingsFile = fullCfg.home.file.".claude/settings.json".source;
  minimalSettingsFile = minimalHooksAndNoStatuslineCfg.home.file.".claude/settings.json".source;
  fullClaudePkg = fullCfg.programs.claude-code.package;
  gwProfileDir = fullCfg.home.file."${fullCfg.xdg.stateHome}/claude-code/profiles/gw-claude.d".source;
  customProfileDir =
    edgeCasesCfg.home.file."${edgeCasesCfg.xdg.stateHome}/claude-code/profiles/custom.d".source;

  artifactsCheck =
    pkgs.runCommand "check-home-claude-code-artifacts"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        set -euo pipefail

        settings=${lib.escapeShellArg fullSettingsFile}
        minimal=${lib.escapeShellArg minimalSettingsFile}
        wrapper=${lib.escapeShellArg "${fullClaudePkg}/bin/claude"}
        gw_dir=${lib.escapeShellArg gwProfileDir}
        custom_dir=${lib.escapeShellArg customProfileDir}

        jq -e '
          ."$schema" == "https://json.schemastore.org/claude-code-settings.json"
          and .permissions.defaultMode == "auto"
          and .permissions.deny == ["Agent(Explore)"]
          and (.permissions.allow | index("Bash(${homeDirectory}/.claude/skills/trusted-skill/scripts/check.sh *)") != null)
          and (.autoMode.environment | any(contains("github.com/example-org")))
          and (.autoMode.allow | index("Custom allow policy for tests.") != null)
          and .enabledPlugins."skill-creator@claude-plugins-official" == true
          and .enabledPlugins."workmux-status@workmux" == true
          and .enabledPlugins."rust-analyzer-lsp@claude-plugins-official" == true
          and .enabledPlugins."custom-plugin@custom-mkt" == true
          and .extraKnownMarketplaces."claude-plugins-official".source.repo == "anthropics/claude-plugins-official"
          and .extraKnownMarketplaces.workmux.source.repo == "raine/workmux"
          and .extraKnownMarketplaces."custom-mkt".source.repo == "example/custom-mkt"
          and .statusLine.command == "claude-statusline"
          and .theme == "light"
          and .env.CUSTOM_CLAUDE_ENV == "yes"
          and (.processWrapper | test("claude-process-wrapper$"))
        ' "$settings" > /dev/null

        jq -e '
          (.hooks.Stop | map(.hooks[]) | any(.type == "command" and (.command | contains("--app claude --claude-stop"))))
          and (.hooks.PermissionRequest | any(.matcher == "AskUserQuestion" and (.hooks | any(.command | contains("--app claude --stdin") and (contains("--claude-stop") | not)))))
          and (.hooks.PostToolUse | length == 2)
          and (.hooks.SessionStart | length == 1)
          and (.hooks.TeammateIdle | length == 1)
          and (.hooks.WorktreeCreate | length == 1)
          and (.hooks.WorktreeRemove | length == 1)
        ' "$settings" > /dev/null

        jq -e '
          (has("statusLine") | not)
          and (.hooks == {})
        ' "$minimal" > /dev/null

        grep -q 'CLAUDE_CODE_CERT_STORE' "$wrapper"
        grep -q 'CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL' "$wrapper"
        grep -q 'profile-loader.sh' "$wrapper"
        grep -q 'session-args.sh' "$wrapper"

        session_args="$(grep -oE '/nix/store/[^"'"'"' ]+session-args\.sh' "$wrapper" | head -n 1)"
        mcp_config="$(grep -oE '/nix/store/[^"'"'"' ]+claude-code-mcp-config\.json' "$session_args" | head -n 1)"
        jq -e '
          (.mcpServers | has("GitHub"))
          and (.mcpServers | has("CustomHttp"))
          and (.mcpServers | has("DeepWiki") | not)
        ' "$mcp_config" > /dev/null

        grep -q 'ANTHROPIC_AUTH_TOKEN' "$gw_dir/env.sh"
        grep -q 'EXTRA_PROVIDER_SECRET' "$gw_dir/env.sh"
        grep -q 'NODE_EXTRA_CA_CERTS' "$gw_dir/env.sh"
        test -f "$gw_dir/agents/architect.md"
        test -f "$gw_dir/agents/reviewer.md"
        test ! -e "$gw_dir/agents/implementer.md"
        grep -q '^name: reviewer$' "$gw_dir/agents/reviewer.md"

        custom_settings="$(grep -oE '/nix/store/[^"'"'"' ]+claude-code-settings-custom\.json' "$custom_dir/env.sh" | head -n 1)"
        jq -e 'has("effortLevel") | not' "$custom_settings" > /dev/null
        ! grep -q '^effort:' "$custom_dir/agents/reviewer.md"

        touch "$out"
      '';
in
{
  home-claude-code = evalCheck;
  home-claude-code-artifacts = artifactsCheck;
}
