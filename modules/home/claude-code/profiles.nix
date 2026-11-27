# ==================================================================================================
# Claude Code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  agentsLib,
  scriptsDir,
  mcpFlag,
}:

let
  inherit (agentsLib.models) modelAliases roleTiers;

  cfg = config.agents.claude-code;
  resolved = config.agents.resolved;
  inherit (cfg.agents) enabledAgents;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/claude-code";
  claudeScriptsDir = scriptsDir + "/claude-code";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  anthropicModels = lib.filterAttrs (
    _: model: (model.channelId or { }) ? anthropic
  ) resolved.modelCatalog.models;

  # Claude Code recognizes catalog keys, and `modelOverrides` maps them to provider IDs.
  clientModelId =
    workload: if workload.channel == "anthropic" then workload.modelKey else workload.modelId;

  aliasModelId =
    workload:
    clientModelId workload + lib.optionalString (workload.model.contextWindow >= 1000000) "[1m]";

  effortFor =
    workload:
    if workload.family != null && resolved.workloadPolicy ? ${workload.family} then
      resolved.workloadPolicy.${workload.family}.${roleTiers.default.effortTier}
    else
      workload.effort;

  mkProfile =
    _: profile:
    let
      inherit (profile) roles workloads;

      defaultTier = lib.findFirst (tier: workloads.${tier}.modelKey == workloads.default.modelKey) null [
        "flagship"
        "standard"
      ];

      defaultModel =
        if defaultTier != null then modelAliases.claude.${defaultTier} else aliasModelId workloads.default;

      aliasEnv =
        lib.mapAttrs' (
          tier: alias:
          lib.nameValuePair "ANTHROPIC_DEFAULT_${lib.toUpper alias}_MODEL" (aliasModelId workloads.${tier})
        ) modelAliases.claude
        // {
          ANTHROPIC_DEFAULT_MODEL = defaultModel;
          CLAUDE_CODE_SUBAGENT_MODEL = modelAliases.claude.${roleTiers.task.modelTier};
        };

      auth = resolved.anthropicProfiles.mkProfileAuth {
        client = "claude-code";
        caEnvVar = "NODE_EXTRA_CA_CERTS";
      } profile;

      smallFastId = clientModelId workloads.mini;

      # Only the Anthropic channel provides `safeguard_results` for server-side auto-mode checks.
      # Other channels use the local auto-mode classifier on the small-fast model.
      autoModeServerOptOut =
        profile.provider != null
        && lib.any (tier: workloads.${tier}.channel != "anthropic") (
          builtins.attrNames modelAliases.claude
        );

      modelEfforts = lib.filterAttrs (_: effort: effort != null && effort != roles.default.effort) (
        lib.listToAttrs (
          map (workload: lib.nameValuePair (clientModelId workload) (effortFor workload)) (
            builtins.attrValues workloads
          )
        )
      );

      compactWindows = lib.listToAttrs (
        map (workload: lib.nameValuePair (clientModelId workload) workload.model.autoCompactTokens) (
          lib.filter (workload: workload.model ? autoCompactTokens) (builtins.attrValues workloads)
        )
      );
    in
    auth
    // {
      extraEnv =
        aliasEnv
        // auth.extraEnv or { }
        // lib.optionalAttrs autoModeServerOptOut {
          CLAUDE_CODE_AUTO_MODE_MODEL = smallFastId;
          CLAUDE_CODE_AUTO_MODE_SERVER = "0";
        };

      inherit (profile) nativeWebSearch;
      sessionEffort = roles.default.effort;

      inherit modelEfforts compactWindows;

      agentModels = lib.mapAttrs (
        tier: workload:
        if tier == "prose" && workload.modelKey != workloads.flagship.modelKey then
          aliasModelId workload
        else if tier == "default" then
          defaultModel
        else
          modelAliases.claude.${tier} or modelAliases.claude.flagship
      ) workloads;

      efforts = lib.filterAttrs (_: effort: effort != null) (
        lib.mapAttrs (_: workload: workload.effort) workloads
      );

      modelOverrides = lib.optionalAttrs (lib.any (workload: workload.channel == "anthropic") (
        builtins.attrValues workloads
      )) (lib.mapAttrs (_: model: model.channelId.anthropic) anthropicModels);
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  resolvedProfiles = resolved.resolveProfiles {
    nativeFamily = "claude";
    client = "claude-code";
  };

  profiles = lib.mapAttrs mkProfile resolvedProfiles;

  officialProfile =
    profiles.official or (mkProfile "official" (
      resolved.profileResolver.resolveProfile {
        name = "official";
        profile = {
          provider = null;
          channel = null;
          family = "claude";
          nativeWebSearch = true;
          oauthTokenFile = null;
        };
      }
    ));

  # ------------------------------------------------------------------------------------------------
  # Profile submodule
  # ------------------------------------------------------------------------------------------------
  profileType = import ./profile-module.nix {
    inherit lib officialProfile;
  };

  # ------------------------------------------------------------------------------------------------
  # Per-profile assertions
  # ------------------------------------------------------------------------------------------------
  fieldConstraints = [
    {
      field = "baseUrl";
      isSet = p: p.baseUrl != null;
      required = [ "api-key" ];
      forbidden = [
        "oauth-token"
        "subscription"
      ];
    }
    {
      field = "tokenFile";
      isSet = p: p.tokenFile != null;
      required = [
        "oauth-token"
        "api-key"
      ];
      forbidden = [ "subscription" ];
    }
    {
      field = "extraEnvFiles";
      isSet = p: p.extraEnvFiles != { };
      forbidden = [ "subscription" ];
    }
  ];

  mkProfileAssertions =
    name: profile:
    let
      prefix = "agents.claude-code: profile '${name}' (${profile.type})";

      fieldAssertions =
        {
          field,
          isSet,
          required ? [ ],
          forbidden ? [ ],
        }:
        lib.optional (required != [ ]) {
          assertion = lib.elem profile.type required -> isSet profile;
          message = "${prefix} requires ${field}";
        }
        ++ lib.optional (forbidden != [ ]) {
          assertion = lib.elem profile.type forbidden -> !isSet profile;
          message = "${prefix} must not set ${field}";
        };

      mkPosixNameAssertion = field: keys: {
        assertion = builtins.all (k: builtins.match "[A-Za-z_][A-Za-z0-9_]*" k != null) keys;
        message = "${prefix} has ${field} keys that are not valid POSIX variable names";
      };
    in
    lib.concatMap fieldAssertions fieldConstraints
    ++ [
      (mkPosixNameAssertion "extraEnv" (builtins.attrNames profile.extraEnv))
      (mkPosixNameAssertion "extraEnvFiles" (builtins.attrNames profile.extraEnvFiles))
    ];

  # ------------------------------------------------------------------------------------------------
  # Custom agents
  # ------------------------------------------------------------------------------------------------
  mkAgentsDir =
    profile:
    let
      agents = import ./agents.nix {
        inherit
          lib
          resolved
          profile
          enabledAgents
          ;
      };
    in
    pkgs.linkFarm "claude-code-agents" (
      lib.mapAttrs' (
        name: text: lib.nameValuePair "${name}.md" (pkgs.writeText "claude-code-agent-${name}.md" text)
      ) agents.files
    );

  # ------------------------------------------------------------------------------------------------
  # Profile bundles
  # ------------------------------------------------------------------------------------------------
  mkProfileBundle =
    name: profile:
    let
      esc = lib.escapeShellArg;

      modelSettings = lib.zipAttrsWith (_: lib.mergeAttrsList) [
        (lib.mapAttrs (_: effortLevel: { inherit effortLevel; }) profile.modelEfforts)
        (lib.mapAttrs (_: autoCompactWindow: { inherit autoCompactWindow; }) profile.compactWindows)
      ];

      settings = json.generate "claude-code-settings-${name}.json" (
        lib.optionalAttrs (profile.sessionEffort != null) {
          effortLevel = profile.sessionEffort;
        }
        // lib.optionalAttrs (modelSettings != { }) {
          inherit modelSettings;
        }
        // lib.optionalAttrs (profile.modelOverrides != { }) {
          inherit (profile) modelOverrides;
        }
        // lib.optionalAttrs (!profile.nativeWebSearch) {
          permissions.deny = [
            "WebSearch"
          ];
        }
      );

      envScript = pkgs.writeShellScript "claude-profile-${name}" (
        lib.concatStringsSep "\n" (
          resolved.anthropicProfiles.mkEnvLines { label = "claude"; } profile
          ++ [ "__claude_settings=${esc settings}" ]
        )
      );
    in
    pkgs.linkFarm "claude-profile-${name}" {
      "env.sh" = envScript;
      agents = mkAgentsDir profile;
    };

  profileBundles = lib.mapAttrs mkProfileBundle cfg.auth.profiles;

  switch = resolved.mkProfileSwitch {
    name = "claude-switch";
    assistant = "Claude Code";
    inherit stateDir;
    extension = "d";
    profiles = profileBundles;
    inherit (cfg.auth) defaultProfile;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile loader and session helpers
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = resolved.anthropicProfiles.mkProfileEnvVars { } cfg.auth.profiles;

  profileLoader = pkgs.replaceVars (claudeScriptsDir + "/profile-loader.sh") {
    inherit stateDir;
    profileEnvVars = toString profileEnvVars;
  };

  sessionArgs = pkgs.replaceVars (claudeScriptsDir + "/session-args.sh") {
    inherit mcpFlag;
  };

  processWrapper = pkgs.writeShellScript "claude-process-wrapper" (
    builtins.replaceStrings [ "@profileLoader@" ] [ "${profileLoader}" ] (
      builtins.readFile (claudeScriptsDir + "/process-wrapper.sh")
    )
  );
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options = agentsLib.profiles.mkOptions { defaultProfile = "official"; } // {
    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = { };
      description = "Named authentication profiles for Claude Code";
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
    ]
    ++ lib.concatLists (lib.mapAttrsToList mkProfileAssertions cfg.auth.profiles);

    # ----------------------------------------------------------------------------------------------
    # Default profiles
    # ----------------------------------------------------------------------------------------------
    agents.claude-code.auth.profiles = lib.mapAttrs (
      _: profile:
      lib.mapAttrs (
        _: value:
        if builtins.isAttrs value then lib.mapAttrs (_: lib.mkDefault) value else lib.mkDefault value
      ) profile
    ) profiles;

    # ----------------------------------------------------------------------------------------------
    # Packages, files, and activation
    # ----------------------------------------------------------------------------------------------
    home = {
      packages = [ switch.package ];

      file = switch.files // {
        ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/active-profile/agents";
      };

      activation.claudeCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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

    "--run"
    "source ${sessionArgs}"
  ];

  settings = {
    processWrapper = "${processWrapper}";
  };
}
