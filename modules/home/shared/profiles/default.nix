# ==================================================================================================
# Shared Models, Providers, and Profiles Module
# ==================================================================================================

{
  agentsLib,
  devkitLib,
  mkNuModules,
  scriptsDir,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents;
  dk = devkitLib.mkLib pkgs;
  nuModules = mkNuModules lib;

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  channelSubmodule = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      family = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Model family served on this provider channel";
      };

      nativeWebSearch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this channel supports native web search";
      };
    };
  };

  providerSubmodule = lib.types.submodule {
    options = {
      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default base URL for this provider";
      };

      apiUrls = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-API endpoint URLs (e.g. anthropic-messages, openai-responses)";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing the default API key";
      };

      clientApiKeyFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-client runtime API key file paths overriding apiKeyFile";
      };

      caCertFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path to a custom CA certificate bundle";
      };

      extraHeaders = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra HTTP headers sent to this provider";
      };

      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra static environment variables exported for this provider";
      };

      extraEnvFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables loaded from runtime file paths";
      };

      wireApi = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default wire API protocol for this provider";
      };

      channels = lib.mkOption {
        type = lib.types.attrsOf channelSubmodule;
        default = { };
        description = "Provider channels and their capabilities";
      };
    };
  };

  profileSubmodule = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Provider name from agents.providers, or null for an official subscription";
      };

      oauthTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing an OAuth token for subscription auth";
      };

      family = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Model family selected by this profile";
      };

      channel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit provider channel pinned for this profile";
      };

      defaultsKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override key in modelCatalog.defaults used to look up tier models";
      };

      proseModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit model key used for the prose workload";
      };

      nativeWebSearch = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Override whether native web search is enabled for this profile";
      };

      clients = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional allowlist of assistant names that receive this profile";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Resolved catalog and profile helpers
  # ------------------------------------------------------------------------------------------------
  resolvedModelCatalog = agentsLib.models.extendCatalog {
    models = cfg.models.catalog;
    inherit (cfg.models) defaults;
  };

  resolvedWorkloadPolicy = lib.recursiveUpdate agentsLib.models.workloadPolicy cfg.models.workloadPolicy;

  profileResolver = agentsLib.profiles.mkResolver {
    modelCatalog = resolvedModelCatalog;
    workloadPolicy = resolvedWorkloadPolicy;
    inherit (cfg) providers;
  };

  resolveProfiles = args: profileResolver.resolveProfiles ({ inherit (cfg) profiles; } // args);

  anthropicProfiles = import ./anthropic.nix {
    inherit lib agentsLib;
    inherit (cfg) providers;
  };

  mkProfileSwitch = import ./switch.nix {
    inherit
      pkgs
      lib
      dk
      scriptsDir
      nuModules
      ;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    _internal = {
      anthropicProfiles = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      mkProfileSwitch = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      modelCatalog = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      profileResolver = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      resolveProfiles = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      workloadPolicy = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };

    models = {
      catalog = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = "Model definitions recursively merged onto the built-in catalog";
      };

      defaults = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Per-family tier defaults and prose model merged onto the built-in defaults";
      };

      workloadPolicy = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        description = "Per-family effort levels per tier merged onto the built-in workload policy";
      };
    };

    providers = lib.mkOption {
      type = lib.types.attrsOf providerSubmodule;
      default = { };
      description = "Model providers referenced by authentication profiles";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileSubmodule;
      default = { };
      description = "Authentication and model-routing profiles shared across assistants";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents._internal = {
    inherit
      anthropicProfiles
      mkProfileSwitch
      profileResolver
      resolveProfiles
      ;
    modelCatalog = resolvedModelCatalog;
    workloadPolicy = resolvedWorkloadPolicy;
  };
}
