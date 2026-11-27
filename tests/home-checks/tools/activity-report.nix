# ==================================================================================================
# Activity Report Home Manager Checks
# ==================================================================================================

fixtures:

let
  inherit (fixtures) desktopCfg headlessCfg headlessServeCfg;
in
[
  {
    name = "activity-report auto-adds Workmux prefix, sets assistants, labels, and skill";
    ok =
      desktopCfg.programs.activity-report.enable
      && desktopCfg.programs.activity-report.skillDirectories == [ ]
      && desktopCfg.programs.activity-report.settings.assistants == desktopCfg.agents.resolved.configDirs
      &&
        desktopCfg.programs.activity-report.settings.excluded_dirs == [
          "/[^/]+__worktrees/workmux-"
          "/tmp/scratch"
        ]
      && desktopCfg.programs.activity-report.settings.labels.default == [ "work" ]
      && desktopCfg.programs.activity-report.settings.custom_flag == true
      && desktopCfg.agents.skills.sources ? activity-report;
  }
  {
    name = "activity-report tracks custom worktree_prefix and omits regex when workmux is disabled";
    ok =
      headlessCfg.programs.activity-report.settings.excluded_dirs == [ "/[^/]+__worktrees/wm\\.v1-" ]
      && !(headlessCfg.agents.skills.sources ? activity-report)
      && !(headlessServeCfg.programs.activity-report.settings ? excluded_dirs);
  }
]
