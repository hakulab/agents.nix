# ==================================================================================================
# OMP Model Configuration
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
  providers,
  profiles,
}:

let
  mkModel =
    {
      channel,
      model,
      modelId,
      ...
    }:
    {
      inherit (model)
        name
        contextWindow
        maxTokens
        input
        reasoning
        thinking
        ;
      id = modelId;
    }
    // lib.optionalAttrs (channel != null && (model.channelBilledCost or { }) ? ${channel}) {
      cost = model.channelBilledCost.${channel};
    }
    // lib.optionalAttrs (channel == null && model ? cost) {
      inherit (model) cost;
    };

  workloadEntries = lib.concatMap (
    profile:
    map (workload: workload // { inherit (profile) provider; }) (builtins.attrValues profile.workloads)
  ) (builtins.attrValues profiles);

  # Every workload of one source shares its API, channel, family, and provider.
  sourceWorkloads = lib.groupBy (entry: entry.source) workloadEntries;

  mkProvider =
    sourceName: entries:
    let
      first = lib.head entries;
      inherit (first) api family;
      apis = lib.unique (map (entry: entry.api) entries);
      families = lib.unique (map (entry: entry.family) entries);
      familyLabels = map (value: if value == null then "null" else value) families;
      entryProviders = lib.unique (map (entry: entry.provider) entries);
      provider = providers.${first.provider};
      tokenFile = agentsLib.profiles.apiKeyFileFor provider "omp";
      baseUrl = provider.apiUrls.${api} or provider.baseUrl;

      compat =
        lib.optionalAttrs (family == "claude") {
          supportsLongCacheRetention = true;
        }
        // lib.optionalAttrs (api == "openai-responses") (
          {
            # Override unrelated bundled-provider compat inherited by custom models.
            supportsReasoningEffort = true;
          }
          // lib.optionalAttrs (family == "gpt") {
            supportsLongPromptCacheRetention = true;
          }
        );
    in
    if builtins.length apis > 1 then
      throw "OMP model source `${sourceName}` mixes APIs: ${lib.concatStringsSep ", " apis}"
    else if builtins.length families > 1 then
      throw "OMP model source `${sourceName}` mixes families: ${lib.concatStringsSep ", " familyLabels}"
    else if builtins.length entryProviders > 1 then
      throw "OMP model source `${sourceName}` mixes providers: ${lib.concatStringsSep ", " entryProviders}"
    else if baseUrl == null then
      throw "OMP model source `${sourceName}` has no baseUrl or apiUrls.${api} on provider `${first.provider}`"
    else
      {
        inherit api baseUrl;
        headers = provider.extraHeaders or { };
        models = lib.unique (map mkModel entries);
      }
      // lib.optionalAttrs (tokenFile != null) {
        auth = "apiKey";
        apiKey = "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg tokenFile}";
        authHeader = true;
      }
      // lib.optionalAttrs (compat != { }) {
        inherit compat;
      };
in
{
  providers = lib.mapAttrs mkProvider sourceWorkloads;
}
