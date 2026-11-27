# ==================================================================================================
# Workmux Home Manager Checks
# ==================================================================================================

{
  lib,
  fixtures,
}:

let
  inherit (fixtures) desktopCfg headlessCfg darwinCfg;
in
[
  {
    name = "workmux installs package, config, 5 bundled skills, OMP extension, and tmux config";
    ok =
      lib.any (pkg: pkg == desktopCfg.agents.workmux.package) desktopCfg.home.packages
      && desktopCfg.xdg.configFile ? "workmux/config.yaml"
      && desktopCfg.home.file ? ".agents/skills/coordinator"
      && desktopCfg.home.file ? ".agents/skills/merge"
      && desktopCfg.home.file ? ".agents/skills/rebase"
      && desktopCfg.home.file ? ".agents/skills/workmux"
      && desktopCfg.home.file ? ".agents/skills/worktree"
      && desktopCfg.home.file ? ".omp/agent/extensions/workmux-status.ts"
      && lib.hasInfix "@workmux_status" desktopCfg.programs.tmux.extraConfig;
  }
  {
    name = "workmux omits OMP extension by default when OMP is disabled and honors opt-out flags";
    ok =
      !(darwinCfg.home.file ? ".omp/agent/extensions/workmux-status.ts")
      && headlessCfg.xdg.configFile ? "workmux/config.yaml"
      && !(headlessCfg.home.file ? ".agents/skills/workmux")
      && !(headlessCfg.home.file ? ".omp/agent/extensions/workmux-status.ts")
      && !(lib.hasInfix "@workmux_status" headlessCfg.programs.tmux.extraConfig);
  }
]
