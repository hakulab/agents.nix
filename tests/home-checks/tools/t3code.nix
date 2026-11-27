# ==================================================================================================
# T3 Code Home Manager Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
  darwinPkgs,
  fixtures,
  hasPkgPrefix,
}:

let
  inherit (fixtures)
    desktopCfg
    headlessCfg
    headlessServeCfg
    darwinCfg
    ;
  inherit (harness) evalModulesWith;

  t3codeProviderCaCfg = evalModulesWith {
    modules = [
      homeModules.t3code
      {
        agents = {
          providers.my-gw = {
            baseUrl = "https://gw.example.test";
            caCertFile = "/run/secrets/provider-ca.pem";
          };

          t3code.enable = true;
        };
      }
    ];
  };

  t3codeMultiProviderCaCfg = evalModulesWith {
    modules = [
      homeModules.t3code
      {
        agents = {
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

          t3code.enable = true;
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
[
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
    name = "t3code caCertFile defaults from a unique provider caCertFile and stays null on ambiguity";
    ok =
      t3codeDefaultCfg.agents.t3code.caCertFile == null
      && t3codeProviderCaCfg.agents.t3code.caCertFile == "/run/secrets/provider-ca.pem"
      && t3codeMultiProviderCaCfg.agents.t3code.caCertFile == null;
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
  {
    name = "T3 Code default and overridden profiles have no failing assertions";
    ok =
      lib.all (a: a.assertion) t3codeProviderCaCfg.assertions
      && lib.all (a: a.assertion) t3codeMultiProviderCaCfg.assertions
      && lib.all (a: a.assertion) t3codeDefaultCfg.assertions
      && lib.all (a: a.assertion) t3codePartialCfg.assertions
      && lib.all (a: a.assertion) t3codeExplicitCfg.assertions
      && lib.all (a: a.assertion) darwinDefaultLabelCfg.assertions;
  }
]
