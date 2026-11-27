# ==================================================================================================
# Codex Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
}:

let
  cfg = config.agents.codex;
  resolved = config.agents.resolved;
  configDir = resolved.configDirs.codex;
  toml = pkgs.formats.toml { };
  stateDir = "${config.xdg.stateHome}/codex";

  mkModelCatalog = import ./models.nix {
    inherit pkgs lib;
    codexPackage = cfg.package;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile resolution
  # ------------------------------------------------------------------------------------------------
  resolvedProfiles = resolved.resolveProfiles {
    nativeFamily = "gpt";
    inherit (cfg.auth) allowedProviders allowedChannels;
    client = "codex";
  };

  providerNames = lib.unique (
    lib.filter (provider: provider != null) (
      lib.mapAttrsToList (_: profile: profile.provider) resolvedProfiles
    )
  );

  referencedProviders = lib.genAttrs providerNames (name: config.agents.providers.${name});

  providerBaseUrl = provider: provider.apiUrls.openai-responses or provider.baseUrl;

  # ------------------------------------------------------------------------------------------------
  # Model providers and runtime environment
  # ------------------------------------------------------------------------------------------------
  mkModelProvider =
    name: provider:
    let
      baseUrl = providerBaseUrl provider;
      tokenFile = agentsLib.profiles.apiKeyFileFor provider "codex";
      wireApi = if provider.wireApi != null then provider.wireApi else "responses";
    in
    {
      inherit name;
      base_url = baseUrl;
      wire_api = wireApi;
    }
    // lib.optionalAttrs (provider.extraHeaders != { }) {
      http_headers = provider.extraHeaders;
    }
    // lib.optionalAttrs (tokenFile != null) {
      auth = {
        command = lib.getExe' pkgs.coreutils "cat";
        args = [ tokenFile ];
      };
    };

  modelProviders = lib.mapAttrs mkModelProvider referencedProviders;

  caCertFiles = lib.unique (
    lib.filter (file: file != null) (
      lib.mapAttrsToList (_: provider: provider.caCertFile) referencedProviders
    )
  );

  providerExtraEnv = lib.foldl' (acc: provider: acc // provider.extraEnv) { } (
    builtins.attrValues referencedProviders
  );

  providerExtraEnvFiles = lib.foldl' (acc: provider: acc // provider.extraEnvFiles) { } (
    builtins.attrValues referencedProviders
  );

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkAgents =
    workloads:
    (import ./agents.nix {
      inherit pkgs lib resolved;
      inherit (cfg.agents) enabledAgents;
      inherit workloads;
    }).settings;

  mkProfile =
    _: profile:
    let
      inherit (profile) roles workloads;
    in
    {
      model = roles.default.modelId;
      model_provider = if profile.provider == null then "openai" else profile.provider;
      model_reasoning_effort = roles.default.effort;
      plan_mode_reasoning_effort = roles.plan.effort;
      agents = {
        default_subagent_model = roles.task.modelId;
        default_subagent_reasoning_effort = roles.task.effort;
      }
      // mkAgents workloads;
      web_search = if profile.nativeWebSearch then "live" else "disabled";
    }
    // lib.optionalAttrs (profile.provider != null) {
      model_catalog_json = toString (mkModelCatalog profile);
    }
    // lib.optionalAttrs (roles.default.family == "gpt") {
      model_auto_compact_token_limit = roles.default.model.autoCompactTokens;
    };

  profiles = lib.mapAttrs mkProfile resolvedProfiles;

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = resolved.mkProfileSwitch {
    name = "codex-switch";
    assistant = "Codex";
    inherit stateDir;
    extension = "config.toml";
    profiles = lib.mapAttrs (name: toml.generate "codex-profile-${name}.toml") profiles;
    inherit (cfg.auth) defaultProfile;
    configFile = "${configDir}/config.toml";
    # Preserve user-defined agents while removing disabled managed roles.
    resetKeys = [
      "model_auto_compact_token_limit"
      "model_catalog_json"
      "agents.explorer"
    ]
    ++ map (name: "agents.${name}") (builtins.attrNames resolved.agentRoles);
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [
      switch.assertion
      {
        assertion = builtins.length caCertFiles <= 1;
        message = "Codex: enabled providers declare multiple distinct caCertFile values, but CODEX_CA_CERTIFICATE accepts only one";
      }
    ]
    ++ lib.mapAttrsToList (name: provider: {
      assertion = providerBaseUrl provider != null;
      message = "Codex: agents.providers.${name} must set apiUrls.openai-responses or baseUrl";
    }) referencedProviders;

    # ----------------------------------------------------------------------------------------------
    # Packages, files, and activation
    # ----------------------------------------------------------------------------------------------
    home = {
      packages = [ switch.package ];
      file = switch.files;

      activation.codexAuthProfile =
        lib.hm.dag.entryAfter
          [
            "codexMutableConfig"
            "linkGeneration"
          ]
          ''
            run ${lib.getExe switch.package} --initialize
          '';
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  inherit profiles stateDir;

  settings = lib.optionalAttrs (modelProviders != { }) {
    model_providers = modelProviders;
  };

  envVars =
    providerExtraEnv
    // lib.optionalAttrs (caCertFiles != [ ]) {
      CODEX_CA_CERTIFICATE = builtins.head caCertFiles;
    };

  envFiles = providerExtraEnvFiles;
}
