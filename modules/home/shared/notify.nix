# ==================================================================================================
# Cross-Platform Notification Module (agents.notify)
# ==================================================================================================
# - macOS: osascript
# - Linux: notify-send
# - WSL: toasty
# ==================================================================================================

{
  devkitLib,
  scriptsDir,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.notify;
  dk = devkitLib.mkLib pkgs;

  # ------------------------------------------------------------------------------------------------
  # Notification packages
  # ------------------------------------------------------------------------------------------------
  defaultToasty =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      pkgs.runCommand "toasty" { } ''
        install -Dm0755 ${
          pkgs.fetchurl {
            url = "https://github.com/shanselman/toasty/releases/download/v0.8.1/toasty-x64.exe";
            hash = "sha256-HGx6JBXNkqEUjPngj9LoX6SOq1dSzj1+D9wfjqH6LaI=";
          }
        } "$out/bin/toasty.exe"
      ''
    else
      null;

  notifyWrapperArgs =
    lib.optionals (cfg.toastyPackage != null) [
      "--set-default"
      "TOASTY_BIN"
      (lib.getExe' cfg.toastyPackage "toasty.exe")
    ]
    ++ lib.optionals (cfg.libnotifyPackage != null) [
      "--set-default"
      "NOTIFY_SEND_BIN"
      (lib.getExe cfg.libnotifyPackage)
    ];

  notifyPackage = dk.writeNuApplication {
    name = "agents-notify";
    text = builtins.readFile (scriptsDir + "/shared/notify/notify.nu");
    makeWrapperArgs = notifyWrapperArgs;
  };

  notifyScript = lib.getExe notifyPackage;

  projectNotifyPackage = dk.writeNuApplication {
    name = "project-notify";
    text = builtins.readFile (scriptsDir + "/shared/notify/project-notify.nu");
    runtimeInputs = [ pkgs.coreutils ];
    flags.notify = notifyScript;
  };

  mkProjectNotifyScript = lib.getExe projectNotifyPackage;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    notify = {
      libnotifyPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = if pkgs.stdenv.isLinux then pkgs.libnotify else null;
        description = "Package providing notify-send for Linux desktop notifications";
      };

      toastyPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = defaultToasty;
        description = "Package providing toasty.exe for WSL toast notifications";
      };
    };

    resolved.notify = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Resolved notification packages and helper script paths";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.resolved.notify = {
    inherit
      notifyPackage
      notifyScript
      projectNotifyPackage
      mkProjectNotifyScript
      ;
  };
}
