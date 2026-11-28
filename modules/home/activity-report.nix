# ==================================================================================================
# Activity Report Module (agents.activity-report)
# ==================================================================================================

{
  activity-report,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.activity-report;
  activityReportPackages = activity-report.packages.${pkgs.stdenv.hostPlatform.system};
  toml = pkgs.formats.toml { };

  workmuxEnabled = config.agents.workmux.enable or false;
  workmuxPrefix = config.agents.workmux.settings.worktree_prefix or "workmux-";

  # Workmux worker sessions count as unattended since prompts come from the launching agent.
  workmuxExcludedDirs = lib.optionals (workmuxEnabled && workmuxPrefix != "") [
    "/[^/]+__worktrees/${lib.strings.escapeRegex workmuxPrefix}"
  ];

  excludedDirs = lib.unique (workmuxExcludedDirs ++ cfg.excludedDirs);

  baseSettings = {
    assistants = { inherit (config.agents.resolved.configDirs) claude codex omp; };
  }
  // lib.optionalAttrs (excludedDirs != [ ]) {
    excluded_dirs = excludedDirs;
  }
  // lib.optionalAttrs (cfg.labels != { }) {
    inherit (cfg) labels;
  };
in
{
  imports = [
    sharedModule
    activity-report.homeModules.default
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.activity-report = {
    enable = lib.mkEnableOption "activity-report worklog generator";

    package = lib.mkOption {
      type = lib.types.package;
      default = activityReportPackages.activity-report;
      description = "Package providing the activity-report CLI and skill";
    };

    excludedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns for project directories excluded from activity reports";
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf toml.type;
      default = { };
      description = "Label rules written to activity-report's [labels] configuration table";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf toml.type;
      default = { };
      description = "Additional settings recursively merged into activity-report/config.toml";
    };

    installSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register the activity-report skill in agents.skills.sources";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    programs.activity-report = {
      enable = true;
      inherit (cfg) package;
      # Managed by agents.skills when installSkill is enabled.
      skillDirectories = [ ];
      settings = lib.recursiveUpdate baseSettings cfg.extraSettings;
    };

    agents.skills.sources = lib.mkIf cfg.installSkill {
      activity-report = lib.mkDefault "${cfg.package}/share/skills/activity-report";
    };
  };
}
