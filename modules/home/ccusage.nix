# ==================================================================================================
# ccusage Module (agents.ccusage)
# ==================================================================================================

{
  llm-agents,
  agentsLib,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.ccusage;
  llmAgentsPackages = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  json = pkgs.formats.json { };

  piStoreSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Display name of the Pi-compatible session store";
      };

      path = lib.mkOption {
        type = lib.types.str;
        description = "Directory path containing session transcripts";
      };
    };
  };

  ompEnabled = config.agents.omp.enable or false;
  hasExplicitOmpStore = lib.any (store: store.name == "omp") cfg.piStores;

  effectivePiStores =
    lib.optionals (ompEnabled && !hasExplicitOmpStore) [
      {
        name = "omp";
        path = "${config.agents.resolved.configDirs.omp}/sessions";
      }
    ]
    ++ cfg.piStores;

  perToken = rate: rate / 1000000.0;

  mkPricingOverride = cost: {
    inputCostPerToken = perToken cost.input;
    outputCostPerToken = perToken cost.output;
    cacheReadInputTokenCost = perToken cost.cacheRead;
    cacheCreationInputTokenCost = perToken cost.cacheWrite;
  };

  activeChannels = lib.unique (
    lib.concatMap (provider: builtins.attrNames provider.channels) (
      builtins.attrValues config.agents.providers
    )
  );

  derivedPricingOverrides = lib.concatMapAttrs (
    _: model:
    lib.concatMapAttrs (
      channel: channelId:
      lib.optionalAttrs (lib.elem channel activeChannels && (model.channelBilledCost or { }) ? ${channel})
        (
          lib.genAttrs (agentsLib.models.channelIds channelId) (
            _: mkPricingOverride model.channelBilledCost.${channel}
          )
        )
    ) (model.channelId or { })
  ) config.agents.resolved.modelCatalog.models;

  effectivePricingOverrides = lib.recursiveUpdate derivedPricingOverrides cfg.pricingOverrides;

  ccusageConfig =
    lib.optionalAttrs (effectivePiStores != [ ]) {
      pi.stores = effectivePiStores;
    }
    // lib.optionalAttrs (effectivePricingOverrides != { }) {
      claude.defaults.pricingOverrides = effectivePricingOverrides;
    };
in
{
  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.ccusage = {
    enable = lib.mkEnableOption "ccusage token and cost tracker";

    package = lib.mkOption {
      type = lib.types.package;
      default = llmAgentsPackages.ccusage;
      description = "Package providing the ccusage CLI";
    };

    piStores = lib.mkOption {
      type = lib.types.listOf piStoreSubmodule;
      default = [ ];
      description = "Pi-compatible session stores registered in ccusage.json";
    };

    pricingOverrides = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Per-model token pricing overrides recursively merged onto catalog-derived channel defaults";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # ccusage discovers configuration for all agents in the Claude XDG config directory.
    xdg.configFile = lib.mkIf (ccusageConfig != { }) {
      "claude/ccusage.json".source = json.generate "ccusage.json" ccusageConfig;
    };
  };
}
