# ==================================================================================================
# Auth Profile Switcher
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
  scriptsDir,
  nuModules,
}:

{
  name,
  assistant,
  stateDir,
  extension,
  profiles,
  defaultProfile,
  configFile ? null,
  resetKeys ? [ ],
}:

let
  json = pkgs.formats.json { };

  profilesDir = "${stateDir}/profiles";

  switchConfig = json.generate "${name}.json" {
    inherit
      assistant
      stateDir
      profilesDir
      extension
      defaultProfile
      configFile
      resetKeys
      ;
  };
in
{
  package = dk.writeNuApplication {
    inherit name;
    text = builtins.readFile (scriptsDir + "/shared/profile-switch/profile-switch.nu");
    runtimeInputs = [ pkgs.coreutils ];
    libDirs = [ nuModules ];
    flags.config = switchConfig;
  };

  files = lib.mapAttrs' (
    profile: source: lib.nameValuePair "${profilesDir}/${profile}.${extension}" { inherit source; }
  ) profiles;

  assertion = {
    assertion = profiles ? ${defaultProfile};
    message = "${assistant}: auth.defaultProfile '${defaultProfile}' is not an enabled profile";
  };
}
