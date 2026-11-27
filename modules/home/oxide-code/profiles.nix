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
  resolvedProfiles = resolved.resolveProfiles {
    nativeFamily = "claude";
    client = "oxide-code";
  };

  # oxide-code speaks only the Anthropic Messages API.
  anthropicOnly = lib.filterAttrs (
    _: profile: profile.roles.default.api == "anthropic-messages"
  ) resolvedProfiles;

  enabledProfiles =
    if cfg.enabledProfiles == null then
      anthropicOnly
    else
      lib.filterAttrs (name: _: lib.elem name cfg.enabledProfiles) anthropicOnly;

  profiles = lib.mapAttrs mkProfile enabledProfiles;

  # ------------------------------------------------------------------------------------------------
  # Profile endpoints
  # ------------------------------------------------------------------------------------------------
  hasValue = value: builtins.isString value && value != "";
  endpointFile = profile: profile.extraEnvFiles.ANTHROPIC_BASE_URL or null;

  hasEndpoint =
    profile:
    hasValue (endpointFile profile)
    || hasValue (profile.extraEnv.ANTHROPIC_BASE_URL or (profile.baseUrl or null))
    || hasValue (config.programs.oxide-code.settings.client.base_url or null);

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkProfileScript =
    name: profile:
    pkgs.writeShellScript "ox-profile-${name}" (
      lib.concatStringsSep "\n" (
        resolved.anthropicProfiles.mkEnvLines { label = "ox"; } profile
        ++ lib.optional (hasValue (endpointFile profile)) ''
          if [[ -z "$ANTHROPIC_BASE_URL" ]]; then
            echo "ox: the profile endpoint file produced an empty ANTHROPIC_BASE_URL" >&2
            return 1
          fi
        ''
      )
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
    assertions = [
      switch.assertion
    ]
    ++ lib.mapAttrsToList (name: profile: {
      assertion = profile.type == "api-key" -> hasEndpoint profile;
      message = "agents.oxide-code: provider profile '${name}' requires an explicit Anthropic endpoint";
    }) profiles;

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
