# ==================================================================================================
# oxide-code Home Manager Module (agents.oxide-code)
# ==================================================================================================

{
  oxide-code,
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
  cfg = config.agents.oxide-code;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      agentsLib
      repoRoot
      ;
  };

  defaultSettings = {
    permission.mode = "yolo";

    tui = {
      show_thinking = true;
      status_line = [
        "current-dir"
        "git-branch"
        "pull-request"
        "pull-request-checks"
        "model-with-effort"
        "context-used"
        "session-cost"
        "five-hour-limit"
        "weekly-limit"
        "task-progress"
        "run-state"
        "thread-title"
      ];
    };
  };
in
{
  imports = [
    sharedModule
    oxide-code.homeModules.default
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.oxide-code = {
    enable = lib.mkEnableOption "oxide-code (ox) coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = oxide-code.packages.${pkgs.stdenv.hostPlatform.system}.oxide-code;
      defaultText = lib.literalExpression "inputs.oxide-code.packages.\${system}.oxide-code";
      description = "oxide-code package to wrap and install";
    };

    auth = profiles.options;

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra settings recursively merged into programs.oxide-code.settings";
    };
  };

  options.agents.resolved.clientProfiles.oxide-code = agentsLib.profiles.mkClientProfilesOption (
    config.agents.resolved.resolveProfiles {
      nativeFamily = "claude";
      client = "oxide-code";
      inherit (cfg.auth) enabledProfiles;
      requiredApi = "anthropic-messages";
    }
  );

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = profiles.wrapArgs ++ agentsLib.proxy.mkProxyWrapArgs config.agents.proxy;

      oxBin = agentsLib.wrapPackage {
        inherit pkgs;
        pkg = cfg.package;
        bin = "ox";
        inherit wrapArgs;
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        home.packages = [
          oxBin
        ];

        programs.oxide-code = {
          enable = true;
          # Config checks cannot load the runtime auth profile. Keep its wrapper first in home.path.
          package = lib.lowPrio cfg.package;
          settings = lib.recursiveUpdate defaultSettings cfg.extraSettings;
        };
      }
    ]
  );
}
