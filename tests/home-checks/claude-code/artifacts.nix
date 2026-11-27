# ==================================================================================================
# Claude Code Rendered Artifact Check
# ==================================================================================================

{
  pkgs,
  nushell,
  harness,
  fixtures,
}:

let
  inherit (harness) homeDirectory;
  inherit (fixtures) fullCfg minimalHooksAndNoStatuslineCfg edgeCasesCfg;

  settingsFile = cfg: cfg.home.file.".claude/settings.json".source;
  profileDir = cfg: name: cfg.home.file."${cfg.xdg.stateHome}/claude-code/profiles/${name}.d".source;
in
pkgs.runCommand "check-home-claude-code-artifacts"
  {
    nativeBuildInputs = [ nushell ];
    HOME_DIRECTORY = homeDirectory;

    ARTIFACTS = builtins.toJSON {
      settings = settingsFile fullCfg;
      minimalSettings = settingsFile minimalHooksAndNoStatuslineCfg;
      wrapper = "${fullCfg.programs.claude-code.package}/bin/claude";
      profiles = {
        gateway = profileDir fullCfg "gw-claude";
        alternate = profileDir fullCfg "gw-alt";
        oauth = profileDir fullCfg "official-token";
        custom = profileDir edgeCasesCfg "custom";
      };
    };
  }
  ''
    nu --no-config-file ${./check-artifacts.nu}
    touch "$out"
  ''
