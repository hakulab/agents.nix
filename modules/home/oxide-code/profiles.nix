# ==================================================================================================
# oxide-code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  shared,
  repoRoot,
}:

let
  cfg = config.agents.oxide-code.auth;
  stateDir = "${config.xdg.stateHome}/oxide-code";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    shared.anthropicProfiles.mkProfileAuth {
      client = "oxide-code";
      caEnvVar = "OX_EXTRA_CA_CERTS";
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  resolvedProfiles = shared.resolveProfiles {
    nativeFamily = "claude";
    client = "oxide-code";
  };

  # oxide-code speaks only the Anthropic Messages API.
  anthropicOnly = lib.filterAttrs (
    _: profile: profile.roles.default.api == "anthropic-messages"
  ) resolvedProfiles;

  enabledProfiles =
    if cfg.profiles == null then
      anthropicOnly
    else
      lib.filterAttrs (name: _: lib.elem name cfg.profiles) anthropicOnly;

  profiles = lib.mapAttrs mkProfile enabledProfiles;

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkProfileScript =
    name: profile:
    pkgs.writeShellScript "ox-profile-${name}" (
      lib.concatStringsSep "\n" (shared.anthropicProfiles.mkEnvLines { label = "ox"; } profile)
    );

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = shared.anthropicProfiles.mkProfileEnvVars {
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
  switch = shared.mkProfileSwitch {
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
  options = agentsLib.profiles.mkOptions { } // {
    profiles = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Optional allowlist of profile names to install for oxide-code";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [ switch.assertion ];

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
