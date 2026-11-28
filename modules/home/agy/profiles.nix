# ==================================================================================================
# Antigravity CLI Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  repoRoot,
}:

let
  inherit (config.agents) providers resolved;
  inherit (config.agents.agy.auth) defaultProfile;

  stateDir = "${config.xdg.stateHome}/agy";
  activeProfile = lib.escapeShellArg "${stateDir}/active-profile";
  profiles = resolved.clientProfiles.agy;
  inherit (import ./models.nix { inherit lib resolved; }) slugFor;

  apiArgsScript = pkgs.writeText "agy-validate-api-args.sh" (
    builtins.readFile (repoRoot + "/scripts/agy/validate-api-args.sh")
  );

  mkProfile =
    name: profile:
    let
      provider = if profile.provider == null then null else providers.${profile.provider};
      keyFile = agentsLib.profiles.apiKeyFileFor provider "agy";
      baseUrl = if provider == null then null else provider.apiUrls.gemini or null;
      settings = builtins.toJSON { modelProvider = if provider == null then "" else "gemini"; };
      model = slugFor profile.roles.default;
      esc = lib.escapeShellArg;
      cat = lib.getExe' pkgs.coreutils "cat";
    in
    pkgs.writeShellScript "agy-profile-${name}" (
      ''
        unset GEMINI_API_KEY GOOGLE_GEMINI_BASE_URL
      ''
      + lib.optionalString (keyFile != null) ''
        source ${apiArgsScript}
        validate_agy_api_args "$@" || exit 1
        if ! GEMINI_API_KEY="$(${cat} ${esc keyFile})" || [ -z "$GEMINI_API_KEY" ]; then
          echo "agy: could not read the API key for profile "${esc name} >&2
          exit 1
        fi
        export GEMINI_API_KEY
      ''
      + lib.optionalString (baseUrl != null) ''
        export GOOGLE_GEMINI_BASE_URL=${esc baseUrl}
      ''
      + ''
        set -- --settings ${esc settings} --model ${esc model} "$@"
      ''
    );

  profileScripts = lib.mapAttrs mkProfile profiles;
  switch = resolved.mkProfileSwitch {
    name = "agy-switch";
    assistant = "Antigravity CLI";
    inherit stateDir defaultProfile;
    extension = "sh";
    profiles = profileScripts;
  };
in
{
  assertions = [ switch.assertion ];
  packages = [ switch.package ];
  inherit (switch) files;
  activation.agyAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe switch.package} --initialize
  '';

  wrapArgs = [
    "--run"
    ''
      if [ -L ${activeProfile} ]; then
        source ${activeProfile} || exit 1
      else
        source ${
          profileScripts.${defaultProfile} or (pkgs.writeShellScript "agy-profile-missing" "exit 1")
        }
      fi
    ''
  ];
}
