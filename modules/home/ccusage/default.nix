# ==================================================================================================
# ccusage Module (agents.ccusage)
# ==================================================================================================

{
  sharedModule,
  llmAgentsPackagesFor,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.ccusage;
  llmAgentsPackages = llmAgentsPackagesFor pkgs.stdenv.hostPlatform.system;
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

  ccusageConfig =
    lib.optionalAttrs (effectivePiStores != [ ]) {
      pi.stores = effectivePiStores;
    }
    // lib.optionalAttrs (cfg.pricingOverrides != { }) {
      claude.defaults.pricingOverrides = cfg.pricingOverrides;
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

    pricingOverrides = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Per-model token pricing overrides written to claude.defaults.pricingOverrides";
    };

    piStores = lib.mkOption {
      type = lib.types.listOf piStoreSubmodule;
      default = [ ];
      description = "Pi-compatible session stores registered in ccusage.json";
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
