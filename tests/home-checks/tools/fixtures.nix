# ==================================================================================================
# Peripheral Tool Integration Fixtures
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
  darwinPkgs,
}:

let
  inherit (harness) evalModulesWith homeDirectory;

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
            pricingOverrides.custom-model = {
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
in
{
  inherit
    sharedOnlyCfg
    defaultCfg
    desktopCfg
    headlessCfg
    headlessServeCfg
    darwinCfg
    ompStubModule
    ;
}
