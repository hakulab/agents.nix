# ==================================================================================================
# Antigravity CLI Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  repoRoot,
  permissionSettings,
}:

let
  inherit (config.agents) providers resolved;
  inherit (config.agents.agy) extraSettings;
  inherit (config.agents.agy.auth) defaultProfile;

  esc = lib.escapeShellArg;
  cat = lib.getExe' pkgs.coreutils "cat";
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/agy";
  profiles = resolved.clientProfiles.agy;
  inherit (import ./models.nix { inherit lib resolved; }) slugFor;

  extraHeaderProfiles = lib.filter (
    name:
    let
      providerName = profiles.${name}.provider;
    in
    providerName != null && (providers.${providerName}.extraHeaders or { }) != { }
  ) (builtins.attrNames profiles);

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    name: profile:
    let
      provider = if profile.provider == null then null else providers.${profile.provider};
      keyFile = agentsLib.profiles.apiKeyFileFor provider "agy";
      baseUrl = if provider == null then null else provider.apiUrls.gemini or null;
      caCertFile = if provider == null then null else provider.caCertFile or null;
      extraEnv = if provider == null then { } else provider.extraEnv or { };
      extraEnvFiles = if provider == null then { } else provider.extraEnvFiles or { };

      settingsFile = json.generate "agy-settings-${name}.json" (
        (lib.recursiveUpdate permissionSettings extraSettings)
        // {
          modelProvider = if provider == null then "" else "gemini";
        }
      );

      model = slugFor profile.roles.default;

      extraEnvLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: "export ${k}=${esc v}") extraEnv
      );

      extraEnvFileLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (var: file: ''
          if ! ${var}="$(${cat} ${esc file})" || [ -z "''${${var}}" ]; then
            echo "agy: could not read ${var} for profile "${esc name} >&2
            exit 1
          fi
          export ${var}
        '') extraEnvFiles
      );
    in
    pkgs.writeShellScript "agy-profile-${name}" (
      lib.optionalString (keyFile != null) ''
        if ! GEMINI_API_KEY="$(${cat} ${esc keyFile})" || [ -z "$GEMINI_API_KEY" ]; then
          echo "agy: could not read the API key for profile "${esc name} >&2
          exit 1
        fi
        export GEMINI_API_KEY
      ''
      + lib.optionalString (baseUrl != null) ''
        export GOOGLE_GEMINI_BASE_URL=${esc baseUrl}
      ''
      + lib.optionalString (caCertFile != null) ''
        export NODE_EXTRA_CA_CERTS=${esc caCertFile}
      ''
      + lib.optionalString (extraEnvLines != "") ''
        ${extraEnvLines}
      ''
      + lib.optionalString (extraEnvFileLines != "") ''
        ${extraEnvFileLines}
      ''
      + ''
        __agy_profile_model=${esc model}
        __agy_profile_settings_file=${esc settingsFile}
      ''
    );

  profileScripts = lib.mapAttrs mkProfile profiles;

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = lib.unique (
    [
      "AGY_ADC_AUTH"
      "GEMINI_API_KEY"
      "GOOGLE_GEMINI_BASE_URL"
      "NODE_EXTRA_CA_CERTS"
    ]
    ++ lib.concatMap (
      profile:
      let
        provider = if profile.provider == null then null else providers.${profile.provider};
      in
      lib.optionals (provider != null) (
        builtins.attrNames (provider.extraEnv or { }) ++ builtins.attrNames (provider.extraEnvFiles or { })
      )
    ) (builtins.attrValues profiles)
  );

  profileLoader = pkgs.replaceVars (repoRoot + "/scripts/agy/profile-loader.sh") {
    inherit stateDir;
    jq = lib.getExe pkgs.jq;
    profileEnvVars = toString profileEnvVars;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = resolved.mkProfileSwitch {
    name = "agy-switch";
    assistant = "Antigravity CLI";
    inherit stateDir defaultProfile;
    extension = "env.sh";
    profiles = profileScripts;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    assertions = [
      switch.assertion
      {
        assertion = extraHeaderProfiles == [ ];
        message = "agents.agy: provider extraHeaders is not supported for profile(s): ${lib.concatStringsSep ", " extraHeaderProfiles}";
      }
    ];

    home = {
      packages = [ switch.package ];
      file = switch.files;

      activation.agyAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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
