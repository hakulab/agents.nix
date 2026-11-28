# ==================================================================================================
# oxide-code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  repoRoot,
}:

let
  cfg = config.agents.oxide-code.auth;
  resolved = config.agents.resolved;
  stateDir = "${config.xdg.stateHome}/oxide-code";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    resolved.anthropicProfiles.mkProfileAuth {
      client = "oxide-code";
      caEnvVar = "OX_EXTRA_CA_CERTS";
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  enabledProfiles = resolved.clientProfiles.oxide-code;

  profiles = lib.mapAttrs mkProfile enabledProfiles;

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkProfileScript =
    name: profile:
    pkgs.writeShellScript "ox-profile-${name}" (
      lib.concatStringsSep "\n" (resolved.anthropicProfiles.mkEnvLines { label = "ox"; } profile)
    );

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = resolved.anthropicProfiles.mkProfileEnvVars {
    extraKnownEnvVars = [
      "NODE_EXTRA_CA_CERTS"
      "OX_EXTRA_CA_CERTS"
    ];
  } profiles;

  profileLoader = pkgs.replaceVars (repoRoot + "/scripts/oxide-code/profile-loader.sh") {
    inherit stateDir;
    profileEnvVars = toString profileEnvVars;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = resolved.mkProfileSwitch {
    name = "ox-switch";
    assistant = "oxide-code";
    inherit stateDir;
    extension = "env.sh";
    profiles = lib.mapAttrs mkProfileScript profiles;
    inherit (cfg) defaultProfile;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options = agentsLib.profiles.mkOptions { };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [ switch.assertion ];

    # ----------------------------------------------------------------------------------------------
    # Packages, files, and activation
    # ----------------------------------------------------------------------------------------------
    home = {
      packages = [ switch.package ];
      file = switch.files;

      activation.oxideCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${lib.getExe switch.package} --initialize
      '';
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  wrapArgs = [
    "--run"
    "source ${profileLoader}"
  ];
}
