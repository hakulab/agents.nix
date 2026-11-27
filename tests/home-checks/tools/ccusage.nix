# ==================================================================================================
# CCUsage Home Manager Checks
# ==================================================================================================

{
  lib,
  harness,
  homeModules,
  fixtures,
}:

let
  inherit (fixtures) desktopCfg headlessCfg ompStubModule;
  inherit (harness) evalModulesWith;

  ompCcusageCfg = evalModulesWith {
    modules = [
      homeModules.ccusage
      ompStubModule
      {
        agents = {
          omp.enable = true;
          ccusage.enable = true;
        };
      }
    ];
  };

  derivedCcusageCfg = evalModulesWith {
    modules = [
      homeModules.ccusage
      {
        agents = {
          models.catalog.claude-opus-5-5 = {
            channelId = {
              gateway = "gw/claude-opus-5-5";
              inactive = "unused/claude-opus-5-5";
            };
            channelBilledCost = {
              gateway = {
                input = 10;
                output = 50;
                cacheRead = 1;
                cacheWrite = 12;
              };
              inactive = {
                input = 99;
                output = 99;
                cacheRead = 99;
                cacheWrite = 99;
              };
            };
          };

          providers.my-gw = {
            baseUrl = "https://gw.example.test";
            channels.gateway.family = "claude";
          };

          ccusage = {
            enable = true;
            pricingOverrides."gw/claude-opus-5-5".outputCostPerToken = 0.0001;
          };
        };
      }
    ];
  };

  derivedCcusageJson =
    builtins.fromJSON
      derivedCcusageCfg.xdg.configFile."claude/ccusage.json".source.value;
in
[
  {
    name = "ccusage auto-registers OMP store and writes claude/ccusage.json without overrides";
    ok =
      ompCcusageCfg.xdg.configFile ? "claude/ccusage.json"
      && lib.any (pkg: pkg == ompCcusageCfg.agents.ccusage.package) ompCcusageCfg.home.packages;
  }
  {
    name = "ccusage writes claude/ccusage.json when piStores and pricingOverrides are configured";
    ok =
      desktopCfg.xdg.configFile ? "claude/ccusage.json"
      && lib.any (pkg: pkg == desktopCfg.agents.ccusage.package) desktopCfg.home.packages;
  }
  {
    name = "ccusage derives baseline pricingOverrides for active provider channels and merges user overrides";
    ok =
      derivedCcusageCfg.xdg.configFile ? "claude/ccusage.json"
      && derivedCcusageJson.claude.defaults.pricingOverrides ? "gw/claude-opus-5-5"
      && derivedCcusageJson.claude.defaults.pricingOverrides ? "claude-opus-5-5"
      && !(derivedCcusageJson.claude.defaults.pricingOverrides ? "unused/claude-opus-5-5")
      &&
        derivedCcusageJson.claude.defaults.pricingOverrides."gw/claude-opus-5-5".inputCostPerToken
        == 0.00001
      &&
        derivedCcusageJson.claude.defaults.pricingOverrides."gw/claude-opus-5-5".outputCostPerToken
        == 0.0001
      &&
        derivedCcusageJson.claude.defaults.pricingOverrides."claude-opus-5-5".outputCostPerToken == 0.00005;
  }
  {
    name = "ccusage omits claude/ccusage.json when neither piStores nor pricingOverrides are set";
    ok =
      !(headlessCfg.xdg.configFile ? "claude/ccusage.json")
      && lib.any (pkg: pkg == headlessCfg.agents.ccusage.package) headlessCfg.home.packages;
  }
  {
    name = "ccusage OMP and derived-pricing profiles have no failing assertions";
    ok =
      lib.all (a: a.assertion) ompCcusageCfg.assertions
      && lib.all (a: a.assertion) derivedCcusageCfg.assertions;
  }
]
