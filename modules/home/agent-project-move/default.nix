# ==================================================================================================
# Agent Project Move Module (agents.agent-project-move)
# ==================================================================================================

{
  sharedModule,
  agentProjectMoveModule,
  agentProjectMovePackagesFor,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.agent-project-move;
  agentProjectMovePackages = agentProjectMovePackagesFor pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    sharedModule
    agentProjectMoveModule
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.agent-project-move = {
    enable = lib.mkEnableOption "agent-project-move session migration CLI";

    package = lib.mkOption {
      type = lib.types.package;
      inherit (agentProjectMovePackages) default;
      description = "Package providing the agent-project-move CLI and skill";
    };

    installSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register the agent-project-move skill in agents.skills.sources";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    programs.agent-project-move = {
      enable = true;
      inherit (cfg) package;
      # Managed by agents.skills when installSkill is enabled.
      skillDirectories = [ ];
    };

    agents.skills.sources = lib.mkIf cfg.installSkill {
      agent-project-move = lib.mkDefault "${cfg.package}/share/skills/agent-project-move";
    };
  };
}
