# ==================================================================================================
# oxide-code Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
}:

let
  inherit (harness) check throws evalHomeWith;

  stubOx = pkgs.writeShellScriptBin "ox" ''
    exit 0
  '';

  stubOmp = pkgs.writeShellScriptBin "omp" ''
    exit 0
  '';

  hasPackageNamed =
    name: packages: lib.any (pkg: (pkg.meta.mainProgram or pkg.name) == name) packages;

  findWrappedPackage =
    name: packages:
    lib.findFirst (
      pkg: (pkg.meta.mainProgram or pkg.name) == name && (pkg.meta.priority or 0) == 0
    ) null packages;

  # ------------------------------------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------------------------------------
  disabledCfg = evalHomeWith [ homeModules.oxide-code ] { };

  defaultPkgCfg = evalHomeWith [ homeModules.oxide-code ] {
    agents.oxide-code.enable = true;
  };

  basicCfg = evalHomeWith [ homeModules.oxide-code ] {
    agents.oxide-code = {
      enable = true;
      package = stubOx;
    };
  };

  combinedCfg =
    evalHomeWith
      [
        homeModules.shared
        homeModules.omp
        homeModules.oxide-code
      ]
      {
        agents = {
          browser.chromiumPackage = null;

          models.catalog = {
            "claude-opus-5-5".channelId.anthropic = "gw/claude-opus-5-5";
            "claude-sonnet-5-5".channelId.anthropic = "gw/claude-sonnet-5-5";
            "claude-haiku-5-5".channelId.anthropic = "gw/claude-haiku-5-5";
          };

          providers.my-gateway = {
            baseUrl = "https://gw.example.test";
            apiUrls = {
              anthropic-messages = "https://gw.example.test/anthropic";
              openai-responses = "https://gw.example.test/openai";
            };
            apiKeyFile = "/run/secrets/gw-default";
            clientApiKeyFiles.oxide-code = "/run/secrets/gw-ox";
            caCertFile = "/run/secrets/gw-ca.pem";
            extraHeaders."x-tenant" = "demo";
            channels.anthropic = {
              family = "claude";
              nativeWebSearch = false;
            };
          };

          profiles = {
            gw-claude = {
              provider = "my-gateway";
              family = "claude";
              channel = "anthropic";
            };

            gw-gpt = {
              provider = "my-gateway";
              family = "gpt";
            };
          };

          omp = {
            enable = true;
            package = stubOmp;
          };

          oxide-code = {
            enable = true;
            package = stubOx;
            auth.defaultProfile = "gw-claude";
            extraSettings.tui.show_thinking = false;
          };
        };
      };

  filteredProfilesCfg = evalHomeWith [ homeModules.oxide-code ] {
    agents = {
      providers.my-gateway = {
        baseUrl = "https://gw.example.test";
        apiKeyFile = "/run/secrets/gw-key";
      };

      profiles.gw-claude = {
        provider = "my-gateway";
        family = "claude";
      };

      oxide-code = {
        enable = true;
        package = stubOx;
        auth.enabledProfiles = [ "official" ];
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Negative assertion fixtures
  # ------------------------------------------------------------------------------------------------
  invalidDefaultCfg = evalHomeWith [ homeModules.oxide-code ] {
    agents.oxide-code = {
      enable = true;
      package = stubOx;
      auth.defaultProfile = "missing-profile";
    };
  };

  stateDir = "${combinedCfg.xdg.stateHome}/oxide-code";
  filteredStateDir = "${filteredProfilesCfg.xdg.stateHome}/oxide-code";

  basicOxBin = findWrappedPackage "ox" basicCfg.home.packages;
  gwClaudeEnv = combinedCfg.home.file."${stateDir}/profiles/gw-claude.env.sh".source.text;
in
check "home-oxide-code" [
  # ------------------------------------------------------------------------------------------------
  # Opt-in, standalone import, and deduplication
  # ------------------------------------------------------------------------------------------------
  {
    name = "oxide-code is disabled by default and leaves programs.oxide-code off";
    ok =
      !disabledCfg.agents.oxide-code.enable
      && !disabledCfg.programs.oxide-code.enable
      && !(hasPackageNamed "ox-switch" disabledCfg.home.packages);
  }
  {
    name = "default oxide-code package resolves to a derivation";
    ok = lib.isDerivation defaultPkgCfg.agents.oxide-code.package;
  }
  {
    name = "standalone and multi-module imports deduplicate cleanly and pass assertions";
    ok =
      lib.all (a: a.assertion) basicCfg.assertions && lib.all (a: a.assertion) combinedCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Program integration and settings
  # ------------------------------------------------------------------------------------------------
  {
    name = "enabling agents.oxide-code wires programs.oxide-code, wrapped ox, and ox-switch";
    ok =
      basicCfg.programs.oxide-code.enable
      && (basicCfg.programs.oxide-code.package.meta.priority or 0) > 0
      && basicOxBin != null
      && lib.hasInfix "profile-loader.sh" basicOxBin.buildCommand
      && hasPackageNamed "ox-switch" basicCfg.home.packages
      && basicCfg.programs.oxide-code.settings.permission.mode == "yolo"
      && basicCfg.programs.oxide-code.settings.tui.show_thinking;
  }
  {
    name = "custom settings merge recursively without dropping default sibling keys";
    ok =
      !combinedCfg.programs.oxide-code.settings.tui.show_thinking
      && combinedCfg.programs.oxide-code.settings.permission.mode == "yolo"
      && builtins.length combinedCfg.programs.oxide-code.settings.tui.status_line == 12;
  }

  # ------------------------------------------------------------------------------------------------
  # Auth profiles and Anthropic-only filtering
  # ------------------------------------------------------------------------------------------------
  {
    name = "Anthropic profiles are installed while non-Anthropic profiles are excluded";
    ok =
      builtins.attrNames combinedCfg.agents.resolved.clientProfiles.oxide-code == [
        "gw-claude"
        "official"
      ]
      && combinedCfg.home.file ? "${stateDir}/profiles/official.env.sh"
      && combinedCfg.home.file ? "${stateDir}/profiles/gw-claude.env.sh"
      && !(combinedCfg.home.file ? "${stateDir}/profiles/gw-gpt.env.sh")
      && combinedCfg.home.activation ? oxideCodeProfile;
  }
  {
    name = "generated profile script exports gateway URL, headers, CA cert, and per-client token";
    ok =
      lib.hasInfix "ANTHROPIC_AUTH_TOKEN" gwClaudeEnv
      && lib.hasInfix "/run/secrets/gw-ox" gwClaudeEnv
      && lib.hasInfix "ANTHROPIC_BASE_URL=${lib.escapeShellArg "https://gw.example.test/anthropic"}" gwClaudeEnv
      && lib.hasInfix "ANTHROPIC_CUSTOM_HEADERS=${lib.escapeShellArg "x-tenant: demo"}" gwClaudeEnv
      && lib.hasInfix "OX_EXTRA_CA_CERTS=${lib.escapeShellArg "/run/secrets/gw-ca.pem"}" gwClaudeEnv;
  }
  {
    name = "auth.enabledProfiles allowlist filters installed profile scripts";
    ok =
      filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/official.env.sh"
      && !(filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/gw-claude.env.sh");
  }
  {
    name = "invalid auth.defaultProfile fails module assertion";
    ok = throws invalidDefaultCfg.assertions;
  }
]
