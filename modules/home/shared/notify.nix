# ==================================================================================================
# Cross-Platform Notification Support
# ==================================================================================================
# - macOS: osascript
# - Linux: notify-send
# - WSL: toasty
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
  scriptsDir,
  notifyCfg,
}:

let
  notifyWrapperArgs =
    lib.optionals (notifyCfg.toastyPackage != null) [
      "--set-default"
      "TOASTY_BIN"
      (lib.getExe' notifyCfg.toastyPackage "toasty.exe")
    ]
    ++ lib.optionals (notifyCfg.libnotifyPackage != null) [
      "--set-default"
      "NOTIFY_SEND_BIN"
      (lib.getExe notifyCfg.libnotifyPackage)
    ];

  notifyPackage = dk.writeNuApplication {
    name = "agents-notify";
    text = builtins.readFile (scriptsDir + "/notify/notify.nu");
    makeWrapperArgs = notifyWrapperArgs;
  };

  notifyScript = lib.getExe notifyPackage;

  projectNotifyPackage = dk.writeNuApplication {
    name = "project-notify";
    text = builtins.readFile (scriptsDir + "/notify/project-notify.nu");
    runtimeInputs = [ pkgs.coreutils ];
    flags.notify = notifyScript;
  };

  mkProjectNotifyScript = lib.getExe projectNotifyPackage;
in
{
  inherit
    mkProjectNotifyScript
    notifyPackage
    notifyScript
    projectNotifyPackage
    ;
}
