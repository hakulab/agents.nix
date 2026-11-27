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
    _: entries:
    let
      first = lib.head entries;
      inherit (first) api family;
      provider = providers.${first.provider};
      tokenFile = agentsLib.profiles.apiKeyFileFor provider "omp";
      baseUrl = provider.apiUrls.${api} or provider.baseUrl;
    in
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
    // lib.optionalAttrs (family == "claude") {
      compat.supportsLongCacheRetention = true;
    }
    // lib.optionalAttrs (api == "openai-responses") {
      compat = {
        # Override unrelated bundled-provider compat inherited by custom models.
        supportsReasoningEffort = true;
      }
      // lib.optionalAttrs (family == "gpt") {
        supportsLongPromptCacheRetention = true;
      };
    };
in
{
  providers = lib.mapAttrs mkProvider sourceWorkloads;
}
