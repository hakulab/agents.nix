# ==================================================================================================
# Provider and Profile Resolution
# ==================================================================================================

{
  lib,
  models,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Provider and channel helpers
  # ------------------------------------------------------------------------------------------------
  apiKeyFileFor =
    provider: client:
    if provider == null then
      null
    else
      provider.clientApiKeyFiles.${client} or provider.apiKeyFile or null;

  modelChannels = model: builtins.attrNames (model.channelId or { });

  selectModelChannel =
    providerChannels: channelAllowed: model:
    let
      channels = lib.filter (ch: providerChannels ? ${ch} && channelAllowed ch) (modelChannels model);
    in
    if channels == [ ] then null else lib.head channels;

  # ------------------------------------------------------------------------------------------------
  # Profile resolver
  # ------------------------------------------------------------------------------------------------
  mkResolver =
    {
      modelCatalog ? models.defaultCatalog,
      workloadPolicy ? models.workloadPolicy,
      roleTiers ? models.roleTiers,
      familyApis ? models.familyApis,
      providers ? { },
    }:
    let
      # --------------------------------------------------------------------------------------------
      # Workload resolution
      # --------------------------------------------------------------------------------------------
      lookupProvider =
        name: providerName:
        if providerName == null then
          { }
        else
          providers.${providerName}
            or (throw "profile `${name}` references undeclared provider `${providerName}`");

      profileTierModels =
        profile:
        let
          defaultsKey = if (profile.defaultsKey or null) != null then profile.defaultsKey else profile.family;
        in
        modelCatalog.defaults.${defaultsKey};

      mkWorkload =
        {
          source,
          channel,
          family,
          modelKey,
          modelId,
          effortTier,
        }:
        let
          model = modelCatalog.models.${modelKey};
          familyApi = if family != null then familyApis.${family} or null else null;
          api = if familyApi != null && lib.elem familyApi model.apis then familyApi else lib.head model.apis;

          effort =
            if family != null && workloadPolicy ? ${family} then
              workloadPolicy.${family}.${effortTier}
            else
              model.thinking.defaultLevel or null;
        in
        {
          inherit
            source
            channel
            family
            modelKey
            modelId
            model
            api
            effort
            ;
        };

      # --------------------------------------------------------------------------------------------
      # Single profile resolution
      # --------------------------------------------------------------------------------------------
      resolveProfile =
        {
          allowedChannels ? null,
          name,
          profile,
        }:
        let
          providerName = profile.provider or null;
          provider = lookupProvider name providerName;
          providerChannels = provider.channels or { };
          tierModels = profileTierModels profile;

          channelAllowed = channel: allowedChannels == null || lib.elem channel allowedChannels;

          resolveModelWorkload =
            {
              modelKey,
              effortTier,
              useProfileChannel ? true,
            }:
            let
              model = modelCatalog.models.${modelKey};

              channel =
                if useProfileChannel && (profile.channel or null) != null then
                  profile.channel
                else if providerName != null && providerChannels != { } then
                  selectModelChannel providerChannels channelAllowed model
                else
                  null;

              channelFamily =
                if channel != null && providerChannels ? ${channel} then
                  providerChannels.${channel}.family or null
                else
                  null;

              family = if channelFamily != null then channelFamily else profile.family or null;

              modelId =
                if channel != null && (model.channelId or { }) ? ${channel} then
                  model.channelId.${channel}
                else
                  modelKey;

              source = if providerName != null && channel != null then "${providerName}-${channel}" else name;
            in
            mkWorkload {
              inherit
                source
                channel
                family
                modelKey
                modelId
                effortTier
                ;
            };

          resolveWorkload =
            {
              modelTier,
              effortTier,
            }:
            resolveModelWorkload {
              modelKey = tierModels.${modelTier};
              inherit effortTier;
            };

          tierWorkloads = lib.mapAttrs (
            tier: _:
            resolveWorkload {
              modelTier = tier;
              effortTier = tier;
            }
          ) tierModels;

          hasExplicitProseModel = (profile.proseModel or null) != null;
          proseModelKey =
            if hasExplicitProseModel then profile.proseModel else modelCatalog.defaults.prose or null;
          proseModel = if proseModelKey != null then modelCatalog.models.${proseModelKey} or null else null;

          proseChannel =
            if proseModel != null && providerName != null && providerChannels != { } then
              selectModelChannel providerChannels channelAllowed proseModel
            else
              null;

          useProseModel =
            proseModel != null
            && (
              if providerName != null && providerChannels != { } then
                proseChannel != null
              else
                hasExplicitProseModel
            );

          proseWorkload =
            if useProseModel then
              resolveModelWorkload {
                modelKey = proseModelKey;
                effortTier = "flagship";
                useProfileChannel = false;
              }
            else
              tierWorkloads.flagship;

          roles = lib.mapAttrs (_: resolveWorkload) roleTiers;

          defaultChannel = roles.default.channel;

          defaultNativeWebSearch =
            if defaultChannel != null && providerChannels ? ${defaultChannel} then
              providerChannels.${defaultChannel}.nativeWebSearch or false
            else
              providerName == null;

          nativeWebSearch =
            if (profile.nativeWebSearch or null) != null then
              profile.nativeWebSearch
            else
              defaultNativeWebSearch;
        in
        builtins.seq provider {
          provider = providerName;
          inherit nativeWebSearch roles;
          oauthTokenFile = profile.oauthTokenFile or null;
          workloads = tierWorkloads // {
            prose = proseWorkload;
          };
        };

      # --------------------------------------------------------------------------------------------
      # Profile filtering and resolution
      # --------------------------------------------------------------------------------------------
      resolveProfiles =
        {
          profiles ? { },
          nativeFamily ? null,
          allowedProviders ? null,
          allowedChannels ? null,
          client ? null,
          enabledProfiles ? null,
          requiredApi ? null,
        }:
        let
          defaultOfficial = lib.optionalAttrs (nativeFamily != null && !(profiles ? official)) {
            official = {
              provider = null;
              channel = null;
              family = nativeFamily;
              nativeWebSearch = true;
              oauthTokenFile = null;
            };
          };

          allProfiles = defaultOfficial // profiles;
          channelAllowed = channel: allowedChannels == null || lib.elem channel allowedChannels;

          profileSupported =
            name: profile:
            let
              providerName = profile.provider or null;
              provider = lookupProvider name providerName;
              providerChannels = provider.channels or { };
              tierModels = profileTierModels profile;

              clientAllowed =
                client == null || (profile.clients or null) == null || lib.elem client profile.clients;

              providerAllowed =
                providerName == null || allowedProviders == null || lib.elem providerName allowedProviders;

              tierChannelsAllowed =
                if providerName == null || providerChannels == { } then
                  true
                else if (profile.channel or null) != null then
                  channelAllowed profile.channel
                else
                  lib.all (
                    modelKey:
                    let
                      model = modelCatalog.models.${modelKey};
                    in
                    modelChannels model == [ ] || selectModelChannel providerChannels channelAllowed model != null
                  ) (builtins.attrValues tierModels);
            in
            builtins.seq provider (clientAllowed && providerAllowed && tierChannelsAllowed);

          supportedProfiles = lib.filterAttrs profileSupported allProfiles;
          resolvedProfiles = lib.mapAttrs (
            name: profile:
            resolveProfile {
              inherit allowedChannels name profile;
            }
          ) supportedProfiles;
        in
        lib.filterAttrs (
          name: profile:
          (requiredApi == null || profile.roles.default.api == requiredApi)
          && (enabledProfiles == null || lib.elem name enabledProfiles)
        ) resolvedProfiles;
    in
    {
      inherit resolveProfile resolveProfiles;
    };

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  mkOptions =
    {
      defaultProfile ? "official",
    }:
    {
      defaultProfile = lib.mkOption {
        type = lib.types.str;
        default = defaultProfile;
        description = "Fallback authentication profile when no installed profile is active";
      };

      enabledProfiles = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional allowlist of profile names to install";
      };
    };

  mkClientProfilesOption =
    profiles:
    lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = profiles;
      defaultText = lib.literalMD "Profiles selected by the client's authentication filters.";
      readOnly = true;
      description = "Profiles available to this client after applying its authentication filters";
    };
in
{
  inherit
    apiKeyFileFor
    mkClientProfilesOption
    mkOptions
    mkResolver
    ;
  inherit (models) modelAliases roleTiers workloadPolicy;
}
