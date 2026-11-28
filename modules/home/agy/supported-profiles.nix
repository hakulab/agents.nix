# ==================================================================================================
# Antigravity CLI Supported Profiles
# ==================================================================================================

{
  config,
  lib,
  agentsLib,
}:

let
  inherit (config.agents) providers resolved;

  supported =
    name: profile:
    let
      provider = providers.${profile.provider} or { };
    in
    profile.family == "gemini"
    && profile.oauthTokenFile == null
    && (
      if profile.provider == null then
        name == "official"
      else
        agentsLib.profiles.apiKeyFileFor provider "agy" != null
        && (
          provider.apiUrls ? gemini
          || provider.baseUrl == "https://generativelanguage.googleapis.com"
          || (provider.baseUrl == null && provider.apiUrls == { })
        )
    );
in
resolved.resolveProfiles {
  profiles = lib.filterAttrs supported config.agents.profiles;
  client = "agy";
  nativeFamily = "gemini";
  inherit (config.agents.agy.auth) enabledProfiles;
}
