# ==================================================================================================
# Anthropic Auth Profiles
# ==================================================================================================
# Profiles for clients configured through Claude Code's environment variables.
# ==================================================================================================

{
  lib,
  agentsLib,
  providers,
}:

let
  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
  };

  knownEnvVars = builtins.attrValues authEnvByType ++ [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_BASE_URL"
    "ANTHROPIC_CUSTOM_HEADERS"
  ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Profile authentication
  # ------------------------------------------------------------------------------------------------
  mkProfileAuth =
    {
      client,
      caEnvVar ? null,
    }:
    profile:
    if (profile.oauthTokenFile or null) != null then
      {
        type = "oauth-token";
        tokenFile = profile.oauthTokenFile;
      }
    else if (profile.provider or null) == null then
      { type = "subscription"; }
    else
      let
        provider = providers.${profile.provider};
        baseUrl = provider.apiUrls.anthropic-messages or provider.baseUrl;
        caEnv = lib.optionalAttrs (caEnvVar != null && (provider.caCertFile or null) != null) {
          ${caEnvVar} = provider.caCertFile;
        };
      in
      {
        type = "api-key";
        inherit baseUrl;
        tokenFile = agentsLib.profiles.apiKeyFileFor provider client;
        extraHeaders = provider.extraHeaders or { };
        extraEnv = (provider.extraEnv or { }) // caEnv;
        extraEnvFiles = provider.extraEnvFiles or { };
      };

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkEnvLines =
    {
      label,
    }:
    profile:
    let
      esc = lib.escapeShellArg;

      needsSecretHelper =
        (profile.type != "subscription" && (profile.tokenFile or null) != null)
        || (profile.extraEnvFiles or { }) != { };

      helperLines = lib.optionals needsSecretHelper [
        ''
          __read_secret() {
            if [[ ! -s "$1" ]]; then
              echo "${label}: secret file missing or empty: $1" >&2
              return 1
            fi
            cat "$1"
          }
        ''
      ];

      tokenLines = lib.optionals (profile.type != "subscription" && (profile.tokenFile or null) != null) (
        let
          sf = esc profile.tokenFile;
          envVar = authEnvByType.${profile.type};
        in
        [
          "${envVar}=\"$(__read_secret ${sf})\""
          "export ${envVar}"
        ]
      );

      extraEnvFileLines = lib.concatLists (
        lib.mapAttrsToList (var: file: [
          "${var}=\"$(__read_secret ${esc file})\""
          "export ${var}"
        ]) (profile.extraEnvFiles or { })
      );

      customHeaders = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "${name}: ${value}") (profile.extraHeaders or { })
      );
    in
    helperLines
    ++ tokenLines
    ++ lib.optional (
      (profile.baseUrl or null) != null
    ) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
    ++ lib.optional (customHeaders != "") "export ANTHROPIC_CUSTOM_HEADERS=${esc customHeaders}"
    ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") (profile.extraEnv or { })
    ++ extraEnvFileLines;

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  # The loader clears these before sourcing the active profile, so no inherited credential,
  # endpoint, or trust bundle can bypass it.
  mkProfileEnvVars =
    {
      extraKnownEnvVars ? [ ],
    }:
    profiles:
    lib.unique (
      lib.naturalSort (knownEnvVars ++ extraKnownEnvVars)
      ++ lib.concatMap (
        profile:
        builtins.attrNames (profile.extraEnv or { }) ++ builtins.attrNames (profile.extraEnvFiles or { })
      ) (builtins.attrValues profiles)
    );
}
