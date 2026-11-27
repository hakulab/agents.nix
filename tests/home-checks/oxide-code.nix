# ==================================================================================================
# oxide-code Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalHomeWith,
  sharedModule,
  ompModule,
  oxideCodeModule,
}:

let
  stubOx = pkgs.writeShellScriptBin "ox" ''
    exit 0
  '';

  hasPackageNamed =
    name: packages: lib.any (pkg: (pkg.meta.mainProgram or pkg.name) == name) packages;

  disabledCfg = evalHomeWith [ oxideCodeModule ] { };

  defaultPkgCfg = evalHomeWith [ oxideCodeModule ] {
    agents.oxide-code.enable = true;
  };

  basicCfg = evalHomeWith [ oxideCodeModule ] {
    agents.oxide-code = {
      enable = true;
      package = stubOx;
    };
  };

  combinedCfg = evalHomeWith [ sharedModule ompModule oxideCodeModule ] {
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
        package = stubOx;
      };

      oxide-code = {
        enable = true;
        package = stubOx;
        auth.defaultProfile = "gw-claude";
        settings.tui.show_thinking = false;
      };
    };
  };

  filteredProfilesCfg = evalHomeWith [ oxideCodeModule ] {
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
        auth.profiles = [ "official" ];
      };
    };
  };

  invalidDefaultCfg = evalHomeWith [ oxideCodeModule ] {
    agents.oxide-code = {
      enable = true;
      package = stubOx;
      auth.defaultProfile = "missing-profile";
    };
  };

  stateDir = "${combinedCfg.xdg.stateHome}/oxide-code";
  filteredStateDir = "${filteredProfilesCfg.xdg.stateHome}/oxide-code";
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
      && hasPackageNamed "ox" basicCfg.home.packages
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
      combinedCfg.home.file ? "${stateDir}/profiles/official.env.sh"
      && combinedCfg.home.file ? "${stateDir}/profiles/gw-claude.env.sh"
      && !(combinedCfg.home.file ? "${stateDir}/profiles/gw-gpt.env.sh")
      && combinedCfg.home.activation ? oxideCodeProfile;
  }
  {
    name = "auth.profiles allowlist filters installed profile scripts";
    ok =
      filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/official.env.sh"
      && !(filteredProfilesCfg.home.file ? "${filteredStateDir}/profiles/gw-claude.env.sh");
  }
  {
    name = "invalid auth.defaultProfile fails module assertion";
    ok = throws invalidDefaultCfg.assertions;
  }
]
