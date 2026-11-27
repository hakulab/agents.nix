# ==================================================================================================
# Claude Code Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
}:

let
  inherit (harness)
    check
    throws
    evalHomeWith
    homeDirectory
    ;

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

            auth.profileOverrides.gw-claude = {
              extraEnv.OVERRIDE_FLAG = "yes";
              extraHeaders."x-override" = "1";
              sessionEffort = "high";
              modelEfforts."claude-opus-5-5" = "max";
              compactWindows."claude-opus-5-5" = 250000;
              modelOverrides."claude-haiku-5-5" = "custom/claude-haiku-5-5";
            };

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
              extraSettings = {
                refresh_interval = 30;
                models."extra-model" = "Extra Model";
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
      name = "profiles install official, gateway anthropic, gateway non-anthropic, and oauth-token bundles";
      ok =
        let
          profilesPrefix = "${fullCfg.xdg.stateHome}/claude-code/profiles";
        in
        fullCfg.home.file ? "${profilesPrefix}/official.d"
        && fullCfg.home.file ? "${profilesPrefix}/gw-claude.d"
        && fullCfg.home.file ? "${profilesPrefix}/gw-alt.d"
        && fullCfg.home.file ? "${profilesPrefix}/official-token.d"
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
      name = "statusline populates catalog models, channelIds, custom models, costSources, and recursive extraSettings";
      ok =
        let
          s = fullCfg.programs.claude-statusline.settings;
        in
        fullCfg.programs.claude-statusline.enable
        && s.models."claude-opus-5-5" == "Claude Opus 5.5"
        && s.models."gw/claude-opus-5-5" == "Claude Opus 5.5"
        && s.models."custom-model" == "Custom Model"
        && s.models."extra-model" == "Extra Model"
        && builtins.length s.cost_sources == 1
        && (builtins.head s.cost_sources).id == "demo-cost"
        && s.refresh_interval == 30;
    }

    # ----------------------------------------------------------------------------------------------
    # Plugins, MCP, and profile edge cases
    # ----------------------------------------------------------------------------------------------
    {
      name = "custom plugin entries merge with built-in defaults and gate workmux plugin on workmux.enable";
      ok =
        let
          p = fullCfg.agents.claude-code.plugins;
        in
        p.marketplaces ? claude-plugins-official
        && !(p.marketplaces ? workmux)
        && p.marketplaces ? custom-mkt
        && p.enabled."skill-creator@claude-plugins-official"
        && !(p.enabled ? "workmux-status@workmux")
        && p.enabled."custom-plugin@custom-mkt";
    }
    {
      name = "per-assistant disabledServers extends global disabledServers and enabledProfiles filters bundles";
      ok =
        let
          profilesPrefix = "${edgeCasesCfg.xdg.stateHome}/claude-code/profiles";
        in
        lib.elem "deepwiki" edgeCasesCfg.agents.claude-code.mcp.disabledServers
        && lib.elem "gitlab" edgeCasesCfg.agents.claude-code.mcp.disabledServers
        && !(edgeCasesCfg.home.file ? "${profilesPrefix}/official.d")
        && !(edgeCasesCfg.home.file ? "${profilesPrefix}/filtered-out.d")
        && edgeCasesCfg.home.file ? "${profilesPrefix}/custom.d"
        && lib.all (a: a.assertion) edgeCasesCfg.assertions;
    }

    # ----------------------------------------------------------------------------------------------
    # Assertions and validation
    # ----------------------------------------------------------------------------------------------
    {
      name = "api-key profile without baseUrl fails assertion";
      ok = hasFailingAssertion missingBaseUrlProfileCfg;
    }
    {
      name = "profileOverrides referencing unknown profile fails assertion";
      ok = hasFailingAssertion unknownOverrideProfileCfg;
    }
    {
      name = "profileOverrides referencing disabled profile fails assertion";
      ok = hasFailingAssertion disabledOverrideProfileCfg;
    }
    {
      name = "non-POSIX extraEnv key in profileOverrides fails assertion";
      ok = hasFailingAssertion invalidEnvNameProfileCfg;
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
  gwAltProfileDir = fullCfg.home.file."${fullCfg.xdg.stateHome}/claude-code/profiles/gw-alt.d".source;
  oauthProfileDir =
    fullCfg.home.file."${fullCfg.xdg.stateHome}/claude-code/profiles/official-token.d".source;
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
        gw_alt_dir=${lib.escapeShellArg gwAltProfileDir}
        oauth_dir=${lib.escapeShellArg oauthProfileDir}
        custom_dir=${lib.escapeShellArg customProfileDir}

        jq -e '
          ."$schema" == "https://json.schemastore.org/claude-code-settings.json"
          and .permissions.defaultMode == "auto"
          and .permissions.deny == ["Agent(Explore)"]
          and (.permissions.allow | index("Bash(${homeDirectory}/.claude/skills/trusted-skill/scripts/check.sh *)") != null)
          and (.autoMode.environment | any(contains("github.com/example-org")))
          and (.autoMode.allow | index("Custom allow policy for tests.") != null)
          and .enabledPlugins."skill-creator@claude-plugins-official" == true
          and (.enabledPlugins | has("workmux-status@workmux") | not)
          and .enabledPlugins."rust-analyzer-lsp@claude-plugins-official" == true
          and .enabledPlugins."custom-plugin@custom-mkt" == true
          and .extraKnownMarketplaces."claude-plugins-official".source.repo == "anthropics/claude-plugins-official"
          and (.extraKnownMarketplaces | has("workmux") | not)
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
        grep -q 'CUSTOM_PROVIDER_FLAG' "$gw_dir/env.sh"
        grep -q 'EXTRA_PROVIDER_SECRET' "$gw_dir/env.sh"
        grep -q 'NODE_EXTRA_CA_CERTS' "$gw_dir/env.sh"
        grep -q 'OVERRIDE_FLAG' "$gw_dir/env.sh"
        grep -q 'x-tenant: demo' "$gw_dir/env.sh"
        grep -q 'x-override: 1' "$gw_dir/env.sh"
        ! grep -q 'CLAUDE_CODE_AUTO_MODE_SERVER' "$gw_dir/env.sh"
        grep -q 'CLAUDE_CODE_AUTO_MODE_SERVER' "$gw_alt_dir/env.sh"
        grep -q 'alt/claude-haiku-5-5' "$gw_alt_dir/env.sh"
        grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$oauth_dir/env.sh"
        test -f "$gw_dir/agents/architect.md"
        test -f "$gw_dir/agents/reviewer.md"
        test ! -e "$gw_dir/agents/implementer.md"
        grep -q '^name: reviewer$' "$gw_dir/agents/reviewer.md"

        gw_settings="$(grep -oE '/nix/store/[^"'"'"' ]+claude-code-settings-gw-claude\.json' "$gw_dir/env.sh" | head -n 1)"
        jq -e '
          .effortLevel == "high"
          and .modelSettings."claude-opus-5-5".effortLevel == "max"
          and .modelSettings."claude-opus-5-5".autoCompactWindow == 250000
          and .modelSettings."claude-sonnet-5-5".autoCompactWindow == 400000
          and .modelOverrides."claude-opus-5-5" == "gw/claude-opus-5-5"
          and .modelOverrides."claude-haiku-5-5" == "custom/claude-haiku-5-5"
        ' "$gw_settings" > /dev/null

        custom_settings="$(grep -oE '/nix/store/[^"'"'"' ]+claude-code-settings-custom\.json' "$custom_dir/env.sh" | head -n 1)"
        jq -e '
          .effortLevel == "low"
          and .permissions.deny == ["WebSearch"]
        ' "$custom_settings" > /dev/null

        touch "$out"
      '';
in
{
  home-claude-code = evalCheck;
  home-claude-code-artifacts = artifactsCheck;
}
