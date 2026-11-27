# ==================================================================================================
# OMP Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  shared,
}:

let
  cfg = config.agents.omp.auth;
  yaml = pkgs.formats.yaml { };
  configDir = shared.configDirs.omp;
  stateDir = "${config.xdg.stateHome}/omp";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    {
      provider,
      workloads,
      ...
    }:
    let
      modelRef =
        workload:
        let
          providerName = if provider == null then "openai-codex" else workload.source;
        in
        "${providerName}/${workload.modelId}";

      mkRole =
        workload:
        if workload.effort != null then "${modelRef workload}:${workload.effort}" else modelRef workload;
    in
    {
      modelRoles = lib.mapAttrs (_: mkRole) workloads // {
        plan = "@flagship";
        task = "@standard";
        slow = "@flagship";
        smol = "@mini";
        tiny = "@mini";
        advisor = "@tiny";
      };

      compaction = {
        enabled = true;
        modelThresholds = lib.listToAttrs (
          map (workload: lib.nameValuePair (modelRef workload) workload.model.autoCompactTokens) (
            builtins.attrValues workloads
          )
        );
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  resolvedProfiles = shared.resolveProfiles {
    nativeFamily = "gpt";
    client = "omp";
  };

  enabledProfiles =
    if cfg.profiles == null then
      resolvedProfiles
    else
      lib.filterAttrs (name: _: lib.elem name cfg.profiles) resolvedProfiles;

  profiles = lib.mapAttrs mkProfile enabledProfiles;

  usedProviders = lib.unique (
    lib.filter (name: name != null) (
      map (profile: profile.provider) (builtins.attrValues enabledProfiles)
    )
  );

  caCertFiles = lib.unique (
    lib.filter (file: file != null) (
      map (name: config.agents.providers.${name}.caCertFile) usedProviders
    )
  );

  models = import ./models.nix {
    inherit pkgs lib agentsLib;
    inherit (config.agents) providers;
    profiles = lib.filterAttrs (_: profile: profile.provider != null) enabledProfiles;
  };

  modelsYaml = yaml.generate "omp-models.yml" models;

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = shared.mkProfileSwitch {
    name = "omp-switch";
    assistant = "OMP";
    inherit stateDir;
    extension = "config.yml";
    profiles = lib.mapAttrs (name: yaml.generate "omp-profile-${name}.yml") profiles;
    inherit (cfg) defaultProfile;
    configFile = "${configDir}/config.yml";
    resetKeys = [
      "modelRoles"
      "compaction.modelThresholds"
    ];
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
      description = "Optional allowlist of profile names to install for OMP";
    };
  };

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
        message = "OMP: enabled providers specify multiple distinct caCertFile paths";
      }
    ];

    home = {
      packages = [ switch.package ];
      file = switch.files;

      activation = {
        # OMP reloads its static model registry only when models.yml's stat mtime changes, and a
        # home-manager store symlink keeps the store's epoch mtime forever, so catalog updates never
        # reach long-running sessions. Install a regular file so activation bumps the mtime.
        ompModelsYaml = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run install -m0600 ${modelsYaml} ${lib.escapeShellArg "${configDir}/models.yml"}
        '';

        # Keep config.yml writable for profile switching and OMP settings updates.
        ompAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run ${lib.getExe switch.package} --initialize
        '';
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  envVars = lib.optionalAttrs (caCertFiles != [ ]) {
    NODE_EXTRA_CA_CERTS = lib.head caCertFiles;
  };
}
