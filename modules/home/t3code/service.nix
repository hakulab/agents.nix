# ==================================================================================================
# T3 Code Background Service (systemd / launchd)
# ==================================================================================================

{
  pkgs,
  lib,
  cfg,
  homeDir,
  baseDir,
  t3CliPkg,
}:

let
  inherit (pkgs.stdenv) isDarwin;

  serveArgs = [
    (lib.getExe t3CliPkg)
    "serve"
  ]
  ++ lib.optionals cfg.lan [ "--lan" ];
in
lib.mkIf cfg.service.enable (
  lib.mkMerge [
    (lib.mkIf (!isDarwin) {
      # --------------------------------------------------------------------------------------------
      # Systemd service (Linux)
      # --------------------------------------------------------------------------------------------
      systemd.user.services.t3code-serve = {
        Unit = {
          Description = "T3 Code headless agent control plane";
          # The interval must outlast five failed starts under stepped backoff (up to 70s each).
          StartLimitIntervalSec = "9min";
          StartLimitBurst = 5;
        };

        Service = {
          Environment = [
            "T3CODE_HOME=${baseDir}"
          ];
          ExecStart = lib.escapeShellArgs serveArgs;
          # `t3 serve` prints a one-time pairing token on every start, so keep stdout out of the
          # journal and pair through `t3 pair`.
          StandardOutput = "null";
          # Without a global DefaultOOMPolicy=continue, an earlyoom kill of one agent process would
          # stop the whole unit.
          OOMPolicy = "continue";
          Restart = "always";
          RestartSec = "5s";
          RestartSteps = 4;
          RestartMaxDelaySec = "1min";
        };

        Install = {
          WantedBy = [
            "default.target"
          ];
        };
      };
    })

    (lib.mkIf isDarwin {
      # --------------------------------------------------------------------------------------------
      # Launchd agent (macOS)
      # --------------------------------------------------------------------------------------------
      launchd.agents.t3code-serve = {
        enable = true;
        config = {
          Label = cfg.service.launchdLabel;
          ProgramArguments = serveArgs;
          WorkingDirectory = homeDir;
          EnvironmentVariables = {
            T3CODE_HOME = baseDir;
          };
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 5;
          StandardOutPath = "/dev/null";
          StandardErrorPath = "${homeDir}/Library/Logs/t3code-serve.log";
        };
      };
    })
  ]
)
