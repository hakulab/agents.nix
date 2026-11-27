# ==================================================================================================
# Provider and Profile Resolution
# ==================================================================================================

{
  lib,
  models,
}:

let
  apiKeyFileFor =
    provider: client:
    if provider == null then
      null
    else
      provider.clientApiKeyFiles.${client} or provider.apiKeyFile or null;

  modelChannels = model: builtins.attrNames (model.channelId or { });

  defaultModelChannel =
    model:
    let
      channels = modelChannels model;
    in
    if channels == [ ] then null else lib.head channels;

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
      # Profile resolution
      # --------------------------------------------------------------------------------------------
      profileTierModels = profile: modelCatalog.defaults.${profile.defaultsKey or profile.family};

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
        in
        {
          inherit
            source
            channel
            family
            modelKey
            modelId
            model
            ;
          api = familyApis.${family} or (lib.head model.apis);
          effort = workloadPolicy.${family}.${effortTier};
        };

      resolveProfile =
        {
          allowedChannels ? null,
          name,
          profile,
        }:
        let
          providerName = profile.provider or null;
          provider = if providerName != null then providers.${providerName} or { } else { };
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
                  defaultModelChannel model
                else
                  null;
              family =
                if channel != null && providerChannels ? ${channel} then
                  providerChannels.${channel}.family or profile.family
                else
                  profile.family;
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

          proseModelKey = profile.proseModel or modelCatalog.defaults.prose or null;
          proseModel = if proseModelKey != null then modelCatalog.models.${proseModelKey} or null else null;
          proseChannel = if proseModel != null then defaultModelChannel proseModel else null;

          useProseModel =
            if (profile.proseModel or null) != null then
              true
            else
              providerName != null
              && providerChannels != { }
              && proseModel != null
              && proseChannel != null
              && channelAllowed proseChannel
              && providerChannels ? ${proseChannel};

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
          nativeWebSearch = profile.nativeWebSearch or defaultNativeWebSearch;
        in
        {
          provider = providerName;
          inherit nativeWebSearch roles;
          oauthTokenFile = profile.oauthTokenFile or null;
          workloads = tierWorkloads // {
            prose = proseWorkload;
          };
        };

      resolveProfiles =
        {
          profiles ? { },
          nativeFamily ? null,
          allowedProviders ? null,
          allowedChannels ? null,
          client ? null,
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
            _: profile:
            let
              providerName = profile.provider or null;
              provider = if providerName != null then providers.${providerName} or { } else { };
              providerChannels = provider.channels or { };
              clientAllowed =
                client == null || (profile.clients or null) == null || lib.elem client profile.clients;
              providerAllowed =
                providerName == null || allowedProviders == null || lib.elem providerName allowedProviders;
              tierModels = profileTierModels profile;
              tierChannelsAllowed =
                if providerName == null || providerChannels == { } then
                  true
                else if (profile.channel or null) != null then
                  channelAllowed profile.channel
                else
                  lib.all (
                    modelKey:
                    let
                      channel = defaultModelChannel modelCatalog.models.${modelKey};
                    in
                    channel == null || channelAllowed channel
                  ) (builtins.attrValues tierModels);
            in
            clientAllowed && providerAllowed && tierChannelsAllowed;

          enabledProfiles = lib.filterAttrs profileSupported allProfiles;
        in
        lib.mapAttrs (
          name: profile:
          resolveProfile {
            inherit allowedChannels name profile;
          }
        ) enabledProfiles;
    in
    {
      inherit
        resolveProfile
        resolveProfiles
        ;
    };

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
    };
in
{
  inherit
    apiKeyFileFor
    mkOptions
    mkResolver
    ;
  inherit (models) modelAliases roleTiers workloadPolicy;
}
