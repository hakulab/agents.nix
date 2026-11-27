# ==================================================================================================
# Context7 Home Manager Checks
# ==================================================================================================

{
  lib,
  fixtures,
  hasPkgPrefix,
}:

let
  inherit (fixtures) desktopCfg headlessCfg;
in
[
  {
    name = "ctx7 wraps package when apiKeyFile is set and uses raw package otherwise";
    ok =
      !(lib.any (pkg: pkg == desktopCfg.agents.ctx7.package) desktopCfg.home.packages)
      && hasPkgPrefix "ctx7-" desktopCfg.home.packages
      && lib.any (pkg: pkg == headlessCfg.agents.ctx7.package) headlessCfg.home.packages;
  }
]
