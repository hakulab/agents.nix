# ==================================================================================================
# Agent Project Move Home Manager Checks
# ==================================================================================================

fixtures:

let
  inherit (fixtures) desktopCfg headlessCfg;
in
[
  {
    name = "agent-project-move enables upstream program and wires skill into agents.skills.sources";
    ok =
      desktopCfg.programs.agent-project-move.enable
      && desktopCfg.programs.agent-project-move.skillDirectories == [ ]
      && desktopCfg.agents.skills.sources ? agent-project-move
      && headlessCfg.programs.agent-project-move.enable
      && !(headlessCfg.agents.skills.sources ? agent-project-move);
  }
]
