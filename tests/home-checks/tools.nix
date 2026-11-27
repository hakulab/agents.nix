# ==================================================================================================
# Peripheral Home Manager Modules Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
  darwinPkgs,
}:

let
  inherit (harness) check evalModulesWith homeDirectory;

  allToolModules = [
    homeModules.acp
    homeModules.activity-report
    homeModules.agent-project-move
    homeModules.ccusage
    homeModules.ctx7
    homeModules.t3code
    homeModules.workmux
  ];

  ompStubModule = {
    options.agents.omp.enable = lib.mkEnableOption "Oh My Pi stub";
  };

  stubBinPkg =
    name:
    pkgs.runCommand name { meta.mainProgram = name; } ''
      mkdir -p "$out/bin"
      printf '#!/bin/sh\nexit 0\n' > "$out/bin/${name}"
      chmod +x "$out/bin/${name}"
    '';

  hasPkgPrefix = prefix: packages: lib.any (pkg: lib.hasPrefix prefix (pkg.name or "")) packages;

  # ------------------------------------------------------------------------------------------------
  # Evaluated profiles
  # ------------------------------------------------------------------------------------------------
  sharedOnlyCfg = evalModulesWith {
    modules = [ homeModules.shared ];
  };

  defaultCfg = evalModulesWith {
    modules = allToolModules;
  };

  desktopCfg = evalModulesWith {
    modules = allToolModules ++ [
      ompStubModule
      {
        programs = {
          claude-code = {
            enable = true;
            package = stubBinPkg "claude";
          };

          codex = {
            enable = true;
            package = stubBinPkg "codex";
          };
        };

        agents = {
          omp.enable = true;

          acp.enable = true;

          activity-report = {
            enable = true;
            excludedDirs = [ "/tmp/scratch" ];
            labels = {
              default = [ "work" ];
              projects.demo = [ "personal" ];
            };
            extraSettings.custom_flag = true;
          };

          agent-project-move.enable = true;

          ccusage = {
            enable = true;
            piStores = [
              {
                name = "extra";
                path = "${homeDirectory}/.extra/sessions";
              }
            ];
            pricingOverrides."custom-model" = {
              inputCostPerToken = 0.000001;
              outputCostPerToken = 0.000002;
            };
          };

          ctx7 = {
            enable = true;
            apiKeyFile = "/run/secrets/context7-api-key";
          };

          t3code = {
            enable = true;
            caCertFile = "/run/secrets/ca.crt";
          };

          workmux.enable = true;
        };
      }
    ];
  };

  headlessCfg = evalModulesWith {
    modules = allToolModules ++ [
      {
        agents = {
          acp = {
            enable = true;
            claudeAdapter.enable = false;
            defaultAgent = "codex";
            timeout = 120;
          };

          activity-report = {
            enable = true;
            installSkill = false;
          };

          agent-project-move = {
            enable = true;
            installSkill = false;
          };

          ccusage.enable = true;
          ctx7.enable = true;

          t3code = {
            enable = true;
            headless = true;
            telemetryOptOut = false;
          };

          workmux = {
            enable = true;
            settings.worktree_prefix = "wm.v1-";
            installSkills = false;
            installOmpExtension = false;
            tmuxIntegration = false;
          };
        };
      }
    ];
  };

  headlessServeCfg = evalModulesWith {
    modules = [
      homeModules.activity-report
      homeModules.t3code
      {
        agents = {
          activity-report.enable = true;

          t3code = {
            enable = true;
            headless = true;
            lan = true;
            service.enable = true;
          };
        };
      }
    ];
  };

  ompCcusageCfg = evalModulesWith {
    modules = [
      homeModules.ccusage
      ompStubModule
      {
        agents = {
          omp.enable = true;
          ccusage.enable = true;
        };
      }
    ];
  };

  t3codeDefaultCfg = evalModulesWith {
    modules = [
      homeModules.t3code
      {
        agents.t3code.enable = true;
      }
    ];
  };

  t3codePartialCfg = evalModulesWith {
    modules = [
      homeModules.t3code
      {
        agents.t3code = {
          enable = true;
          settings.defaultRuntimeMode = "manual";
          providerInstances.codex.enabled = false;
        };
      }
    ];
  };

  t3codeExplicitCfg = evalModulesWith {
    modules = [
      homeModules.t3code
      {
        agents.t3code = {
          enable = true;

          settings = {
            defaultRuntimeMode = "manual";
            pullRequestMergeMethod = "squash";
          };

          providerInstances = {
            claudeAgent = {
              driver = "claudeAgent";
              enabled = true;
              config.binaryPath = "claude";
            };

            codex = {
              driver = "codex";
              enabled = false;
              config.binaryPath = "codex";
            };

            omp = {
              driver = "acpRegistry";
              displayName = "Oh My Pi";
              enabled = true;
              config = {
                source = "local";
                agentId = "";
                commandPath = "omp";
                commandArgs = [ "acp" ];
              };
            };
          };
        };
      }
    ];
  };

  darwinCfg = evalModulesWith {
    evalPkgs = darwinPkgs;
    modules = allToolModules ++ [
      {
        agents = {
          acp.enable = true;
          activity-report.enable = true;
          agent-project-move.enable = true;
          ccusage.enable = true;
          ctx7.enable = true;

          t3code = {
            enable = true;
            lan = true;
            service.launchdLabel = "org.example.t3code";
          };

          workmux.enable = true;
        };
      }
    ];
  };

  darwinDefaultLabelCfg = evalModulesWith {
    evalPkgs = darwinPkgs;
    modules = [
      homeModules.t3code
      {
        agents.t3code.enable = true;
      }
    ];
  };
in
check "home-peripheral-tools" [
  # ------------------------------------------------------------------------------------------------
  # Default opt-in and module deduplication
  # ------------------------------------------------------------------------------------------------
  {
    name = "all 7 peripheral modules import together cleanly and default to disabled";
    ok =
      !defaultCfg.agents.acp.enable
      && !defaultCfg.agents.activity-report.enable
      && !defaultCfg.agents.agent-project-move.enable
      && !defaultCfg.agents.ccusage.enable
      && !defaultCfg.agents.ctx7.enable
      && !defaultCfg.agents.t3code.enable
      && !defaultCfg.agents.workmux.enable;
  }
  {
    name = "disabled peripheral modules add no packages";
    ok = defaultCfg.home.packages == sharedOnlyCfg.home.packages;
  }
  {
    name = "disabled peripheral modules create no tool config files";
    ok =
      !(defaultCfg.home.file ? ".acpx/config.json")
      && !(defaultCfg.xdg.configFile ? "claude/ccusage.json")
      && !(defaultCfg.xdg.configFile ? "workmux/config.yaml");
  }
  {
    name = "disabled peripheral modules register no background services";
    ok =
      !(defaultCfg.systemd.user.services ? t3code-serve) && !(defaultCfg.launchd.agents ? t3code-serve);
  }
  {
    name = "all evaluated profiles have no failing assertions";
    ok =
      lib.all (a: a.assertion) sharedOnlyCfg.assertions
      && lib.all (a: a.assertion) defaultCfg.assertions
      && lib.all (a: a.assertion) desktopCfg.assertions
      && lib.all (a: a.assertion) headlessCfg.assertions
      && lib.all (a: a.assertion) headlessServeCfg.assertions
      && lib.all (a: a.assertion) ompCcusageCfg.assertions
      && lib.all (a: a.assertion) t3codeDefaultCfg.assertions
      && lib.all (a: a.assertion) t3codePartialCfg.assertions
      && lib.all (a: a.assertion) t3codeExplicitCfg.assertions
      && lib.all (a: a.assertion) darwinCfg.assertions
      && lib.all (a: a.assertion) darwinDefaultLabelCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # ACP (agents.acp)
  # ------------------------------------------------------------------------------------------------
  {
    name = "acp installs acpx and enabled adapters and writes ~/.acpx/config.json";
    ok =
      hasPkgPrefix "acpx-" desktopCfg.home.packages
      && hasPkgPrefix "claude-agent-acp-" desktopCfg.home.packages
      && hasPkgPrefix "codex-acp-" desktopCfg.home.packages
      && desktopCfg.home.file ? ".acpx/config.json";
  }
  {
    name = "acp auto-targets wrapped claude and codex executables when those programs are enabled";
    ok =
      desktopCfg.agents.acp.claudeAdapter.executable != null
      && lib.hasSuffix "/bin/claude" desktopCfg.agents.acp.claudeAdapter.executable
      && desktopCfg.agents.acp.codexAdapter.executable != null
      && lib.hasSuffix "/bin/codex" desktopCfg.agents.acp.codexAdapter.executable;
  }
  {
    name = "acp omits disabled adapters and leaves executables null when programs are disabled";
    ok =
      headlessCfg.agents.acp.claudeAdapter.executable == null
      && headlessCfg.agents.acp.codexAdapter.executable == null
      && !(hasPkgPrefix "claude-agent-acp-" headlessCfg.home.packages)
      && hasPkgPrefix "codex-acp-" headlessCfg.home.packages
      && hasPkgPrefix "acpx-" headlessCfg.home.packages;
  }

  # ------------------------------------------------------------------------------------------------
  # activity-report (agents.activity-report)
  # ------------------------------------------------------------------------------------------------
  {
    name = "activity-report auto-adds Workmux prefix, sets assistants, labels, and skill";
    ok =
      desktopCfg.programs.activity-report.enable
      && desktopCfg.programs.activity-report.skillDirectories == [ ]
      && desktopCfg.programs.activity-report.settings.assistants == desktopCfg.agents.resolved.configDirs
      &&
        desktopCfg.programs.activity-report.settings.excluded_dirs == [
          "/[^/]+__worktrees/workmux-"
          "/tmp/scratch"
        ]
      && desktopCfg.programs.activity-report.settings.labels.default == [ "work" ]
      && desktopCfg.programs.activity-report.settings.custom_flag == true
      && desktopCfg.agents.skills.sources ? activity-report;
  }
  {
    name = "activity-report tracks custom worktree_prefix and omits regex when workmux is disabled";
    ok =
      headlessCfg.programs.activity-report.settings.excluded_dirs == [ "/[^/]+__worktrees/wm\\.v1-" ]
      && !(headlessCfg.agents.skills.sources ? activity-report)
      && !(headlessServeCfg.programs.activity-report.settings ? excluded_dirs);
  }

  # ------------------------------------------------------------------------------------------------
  # agent-project-move (agents.agent-project-move)
  # ------------------------------------------------------------------------------------------------
  {
    name = "agent-project-move enables upstream program and wires skill into agents.skills.sources";
    ok =
      desktopCfg.programs.agent-project-move.enable
      && desktopCfg.programs.agent-project-move.skillDirectories == [ ]
      && desktopCfg.agents.skills.sources ? agent-project-move
      && headlessCfg.programs.agent-project-move.enable
      && !(headlessCfg.agents.skills.sources ? agent-project-move);
  }

  # ------------------------------------------------------------------------------------------------
  # ccusage (agents.ccusage)
  # ------------------------------------------------------------------------------------------------
  {
    name = "ccusage auto-registers OMP store and writes claude/ccusage.json without overrides";
    ok =
      ompCcusageCfg.xdg.configFile ? "claude/ccusage.json"
      && lib.any (pkg: pkg == ompCcusageCfg.agents.ccusage.package) ompCcusageCfg.home.packages;
  }
  {
    name = "ccusage writes claude/ccusage.json when piStores and pricingOverrides are configured";
    ok =
      desktopCfg.xdg.configFile ? "claude/ccusage.json"
      && lib.any (pkg: pkg == desktopCfg.agents.ccusage.package) desktopCfg.home.packages;
  }
  {
    name = "ccusage omits claude/ccusage.json when neither piStores nor pricingOverrides are set";
    ok =
      !(headlessCfg.xdg.configFile ? "claude/ccusage.json")
      && lib.any (pkg: pkg == headlessCfg.agents.ccusage.package) headlessCfg.home.packages;
  }

  # ------------------------------------------------------------------------------------------------
  # Context7 (agents.ctx7)
  # ------------------------------------------------------------------------------------------------
  {
    name = "ctx7 wraps package when apiKeyFile is set and uses raw package otherwise";
    ok =
      !(lib.any (pkg: pkg == desktopCfg.agents.ctx7.package) desktopCfg.home.packages)
      && hasPkgPrefix "ctx7-" desktopCfg.home.packages
      && lib.any (pkg: pkg == headlessCfg.agents.ctx7.package) headlessCfg.home.packages;
  }

  # ------------------------------------------------------------------------------------------------
  # T3 Code (agents.t3code)
  # ------------------------------------------------------------------------------------------------
  {
    name = "t3code desktop installs desktop package, activation entry, and enables background service";
    ok =
      hasPkgPrefix "t3code-" desktopCfg.home.packages
      && !(hasPkgPrefix "t3code-cli-" desktopCfg.home.packages)
      && desktopCfg.home.activation ? t3codeMutableConfig
      && desktopCfg.agents.t3code.service.enable;
  }
  {
    name = "t3code desktop configures systemd service on Linux and launchd agent on Darwin";
    ok =
      if pkgs.stdenv.isDarwin then
        desktopCfg.launchd.agents ? t3code-serve
        && desktopCfg.launchd.agents.t3code-serve.config.Label == "org.agents-nix.t3code"
      else
        desktopCfg.systemd.user.services ? t3code-serve
        && desktopCfg.systemd.user.services.t3code-serve.Service.OOMPolicy == "continue"
        && desktopCfg.systemd.user.services.t3code-serve.Service.StandardOutput == "null"
        && !(lib.any (lib.hasInfix "--lan") (
          lib.toList desktopCfg.systemd.user.services.t3code-serve.Service.ExecStart
        ));
  }
  {
    name = "t3code partial settings and providerInstances overrides preserve defaults";
    ok =
      t3codePartialCfg.home.activation.t3codeMutableConfig.data
      == t3codeExplicitCfg.home.activation.t3codeMutableConfig.data
      &&
        t3codePartialCfg.home.activation.t3codeMutableConfig.data
        != t3codeDefaultCfg.home.activation.t3codeMutableConfig.data;
  }
  {
    name = "t3code headless installs CLI-only package and disables background service by default";
    ok =
      hasPkgPrefix "t3code-cli-" headlessCfg.home.packages
      && !headlessCfg.agents.t3code.service.enable
      && !(headlessCfg.systemd.user.services ? t3code-serve)
      && !(headlessCfg.launchd.agents ? t3code-serve);
  }
  {
    name = "t3code headless with explicit service.enable and lan passes --lan to t3 serve";
    ok =
      if pkgs.stdenv.isDarwin then
        lib.elem "--lan" headlessServeCfg.launchd.agents.t3code-serve.config.ProgramArguments
      else
        lib.any (lib.hasInfix "--lan") (
          lib.toList headlessServeCfg.systemd.user.services.t3code-serve.Service.ExecStart
        );
  }
  {
    name = "t3code Darwin profile configures launchd agent with default and custom labels";
    ok =
      darwinDefaultLabelCfg.launchd.agents ? t3code-serve
      && darwinDefaultLabelCfg.launchd.agents.t3code-serve.config.Label == "org.agents-nix.t3code"
      &&
        darwinDefaultLabelCfg.launchd.agents.t3code-serve.config.EnvironmentVariables.T3CODE_HOME
        == "/Users/tester/.t3"
      && !(darwinDefaultLabelCfg.systemd.user.services ? t3code-serve)
      && darwinCfg.launchd.agents.t3code-serve.config.Label == "org.example.t3code"
      && lib.elem "--lan" darwinCfg.launchd.agents.t3code-serve.config.ProgramArguments;
  }

  # ------------------------------------------------------------------------------------------------
  # Workmux (agents.workmux)
  # ------------------------------------------------------------------------------------------------
  {
    name = "workmux installs package, config, 5 bundled skills, OMP extension, and tmux config";
    ok =
      lib.any (pkg: pkg == desktopCfg.agents.workmux.package) desktopCfg.home.packages
      && desktopCfg.xdg.configFile ? "workmux/config.yaml"
      && desktopCfg.home.file ? ".agents/skills/coordinator"
      && desktopCfg.home.file ? ".agents/skills/merge"
      && desktopCfg.home.file ? ".agents/skills/rebase"
      && desktopCfg.home.file ? ".agents/skills/workmux"
      && desktopCfg.home.file ? ".agents/skills/worktree"
      && desktopCfg.home.file ? ".omp/agent/extensions/workmux-status.ts"
      && lib.hasInfix "@workmux_status" desktopCfg.programs.tmux.extraConfig;
  }
  {
    name = "workmux omits OMP extension by default when OMP is disabled and honors opt-out flags";
    ok =
      !(darwinCfg.home.file ? ".omp/agent/extensions/workmux-status.ts")
      && headlessCfg.xdg.configFile ? "workmux/config.yaml"
      && !(headlessCfg.home.file ? ".agents/skills/workmux")
      && !(headlessCfg.home.file ? ".omp/agent/extensions/workmux-status.ts")
      && !(lib.hasInfix "@workmux_status" headlessCfg.programs.tmux.extraConfig);
  }
]
