# ==================================================================================================
# Peripheral Home Manager Module Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
  darwinPkgs,
}:

let
  inherit (harness) check;

  fixtures = import ./fixtures.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      darwinPkgs
      ;
  };

  inherit (fixtures)
    sharedOnlyCfg
    defaultCfg
    desktopCfg
    headlessCfg
    headlessServeCfg
    darwinCfg
    ;

  hasPkgPrefix = prefix: packages: lib.any (pkg: lib.hasPrefix prefix (pkg.name or "")) packages;

  integrationChecks = [
    {
      name = "all 7 peripheral modules import together cleanly and default to disabled";
      ok =
        !defaultCfg.agents.acp.enable
        && !defaultCfg.agents.activity-report.enable
        && !defaultCfg.agents.agent-project-move.enable
        && !defaultCfg.agents.ccusage.enable
        && !defaultCfg.agents.ctx7.enable
        && !defaultCfg.agents.t3code.enable
        && !defaultCfg.agents.workmux.enable;
    }
    {
      name = "disabled peripheral modules add no packages";
      ok = defaultCfg.home.packages == sharedOnlyCfg.home.packages;
    }
    {
      name = "disabled peripheral modules create no tool config files";
      ok =
        !(defaultCfg.home.file ? ".acpx/config.json")
        && !(defaultCfg.xdg.configFile ? "claude/ccusage.json")
        && !(defaultCfg.xdg.configFile ? "workmux/config.yaml");
    }
    {
      name = "disabled peripheral modules register no background services";
      ok =
        !(defaultCfg.systemd.user.services ? t3code-serve) && !(defaultCfg.launchd.agents ? t3code-serve);
    }
    {
      name = "shared peripheral profiles have no failing assertions";
      ok =
        lib.all (a: a.assertion) sharedOnlyCfg.assertions
        && lib.all (a: a.assertion) defaultCfg.assertions
        && lib.all (a: a.assertion) desktopCfg.assertions
        && lib.all (a: a.assertion) headlessCfg.assertions
        && lib.all (a: a.assertion) headlessServeCfg.assertions
        && lib.all (a: a.assertion) darwinCfg.assertions;
    }
  ];
in
check "home-peripheral-tools" (
  integrationChecks
  ++ import ./acp.nix { inherit lib fixtures hasPkgPrefix; }
  ++ import ./activity-report.nix fixtures
  ++ import ./agent-project-move.nix fixtures
  ++ import ./ccusage.nix {
    inherit
      lib
      harness
      homeModules
      fixtures
      ;
  }
  ++ import ./ctx7.nix { inherit lib fixtures hasPkgPrefix; }
  ++ import ./t3code.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      darwinPkgs
      fixtures
      hasPkgPrefix
      ;
  }
  ++ import ./workmux.nix { inherit lib fixtures; }
)
