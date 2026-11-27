# ==================================================================================================
# T3 Code Module (agents.t3code)
# ==================================================================================================

{
  nixpkgs-unstable,
  devkit,
  agentsLib,
  repoRoot,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.t3code;
  proxyCfg = config.agents.proxy;
  unstablePackages = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  dk = devkit.lib.mkLib pkgs;
  json = pkgs.formats.json { };

  homeDir = config.home.homeDirectory;
  baseDir = "${homeDir}/.t3";

  # ------------------------------------------------------------------------------------------------
  # Package wrappers
  # ------------------------------------------------------------------------------------------------
  # The agent CLIs, git, gh, and glab come from the Home Manager profile, since the nixpkgs
  # wrapper's own PATH entries would shadow them.
  defaultPackage = unstablePackages.t3code.override {
    enableClaude = false;
    enableCodex = false;
    enableGit = false;
    enableGitHub = false;
    enableGitLab = false;
  };

  runtimePath = lib.makeBinPath [
    config.home.profileDirectory
    pkgs.coreutils
  ];

  baseWrapArgs = [
    "--prefix"
    "PATH"
    ":"
    runtimePath
  ]
  ++ agentsLib.proxy.mkProxyWrapArgs proxyCfg;

  # Electron cancels fetch when NODE_USE_ENV_PROXY=1 is set, so only the CLI server exports it.
  cliWrapArgs =
    baseWrapArgs
    ++ lib.optionals proxyCfg.enable [
      "--run"
      agentsLib.proxy.nodeProxyScript
    ];

  envVars =
    lib.optionalAttrs cfg.telemetryOptOut {
      T3CODE_OTEL_SDK_DISABLED = "true";
      T3CODE_POSTHOG_HOST = "http://127.0.0.1:0";
      T3CODE_TELEMETRY_ENABLED = "false";
    }
    // lib.optionalAttrs (cfg.caCertFile != null) {
      NODE_EXTRA_CA_CERTS = cfg.caCertFile;
    };

  t3CliPkg = agentsLib.wrapPackage {
    inherit pkgs;
    pkg = cfg.package;
    name = "t3code-cli-${cfg.package.version or cfg.package.name}";
    bin = "t3";
    wrapArgs = cliWrapArgs;
    inherit envVars;
  };

  t3DesktopPkg = agentsLib.wrapPackage {
    inherit pkgs;
    pkg = t3CliPkg;
    name = cfg.package.name;
    bin = "t3code-desktop";
    wrapArgs = baseWrapArgs;
    inherit envVars;
  };

  # Headless hosts expose only the CLI, leaving the Electron app off PATH and out of menus.
  t3HeadlessPkg = pkgs.runCommandLocal t3CliPkg.name { meta.mainProgram = "t3"; } ''
    mkdir --parents "$out/bin"
    ln --symbolic ${lib.getExe t3CliPkg} "$out/bin/t3"
  '';

  # ------------------------------------------------------------------------------------------------
  # Config activation
  # ------------------------------------------------------------------------------------------------
  defaultSettings = {
    defaultRuntimeMode = "auto";
    pullRequestMergeMethod = "squash";
  };

  defaultProviderInstances = {
    claudeAgent = {
      driver = "claudeAgent";
      enabled = true;
      config = {
        binaryPath = "claude";
      };
    };

    codex = {
      driver = "codex";
      enabled = true;
      config = {
        binaryPath = "codex";
      };
    };

    omp = {
      driver = "acpRegistry";
      displayName = "Oh My Pi";
      enabled = true;
      config = {
        source = "local";
        agentId = "";
        commandPath = "omp";
        commandArgs = [
          "acp"
        ];
      };
    };
  };

  mergedSettings = lib.recursiveUpdate defaultSettings cfg.settings;
  mergedProviderInstances = lib.recursiveUpdate defaultProviderInstances cfg.providerInstances;

  activateConfig = dk.writeNuApplication {
    name = "activate-t3code-config";
    text = builtins.readFile (repoRoot + "/scripts/t3code/activate-config.nu");
    runtimeInputs = [ pkgs.coreutils ];
    libDirs = [ config.agents._internal.nuModules ];
    flags.config = json.generate "activate-t3code-config.json" {
      inherit baseDir;
      providerInstances = mergedProviderInstances;
      defaults = mergedSettings;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Background service
  # ------------------------------------------------------------------------------------------------
  serviceConfig = import ./service.nix {
    inherit
      pkgs
      lib
      cfg
      homeDir
      baseDir
      t3CliPkg
      ;
  };
in
{
  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.t3code = {
    enable = lib.mkEnableOption "T3 Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Package providing the t3 CLI and t3code-desktop binaries";
    };

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install only the headless t3 CLI without the desktop Electron app";
    };

    lan = lib.mkEnableOption "serving the LAN and tailnet (defaults to loopback only)";

    caCertFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to an extra CA certificate bundle exported as NODE_EXTRA_CA_CERTS";
    };

    telemetryOptOut = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable T3 Code OpenTelemetry and PostHog telemetry";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Managed default settings recursively merged onto built-in defaults for T3 Code userdata/settings.json";
    };

    providerInstances = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Provider instances recursively merged onto built-in defaults for T3 Code userdata/settings.json";
    };

    service = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = !cfg.headless;
        description = "Run t3 serve as a user background service (systemd on Linux, launchd on macOS)";
      };

      launchdLabel = lib.mkOption {
        type = lib.types.str;
        default = "org.agents-nix.t3code";
        description = "launchd agent label on macOS";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [
          (if cfg.headless then t3HeadlessPkg else t3DesktopPkg)
        ];

        home.activation.t3codeMutableConfig =
          lib.hm.dag.entryBetween
            [
              "reloadSystemd"
              "setupLaunchAgents"
            ]
            [ "writeBoundary" ]
            ''
              run ${lib.getExe activateConfig}
            '';
      }

      serviceConfig
    ]
  );
}
