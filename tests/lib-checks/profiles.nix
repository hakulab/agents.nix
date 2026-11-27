# ==================================================================================================
# Profile Resolution Checks
# ==================================================================================================

{
  agentsLib,
  check,
  throws,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Catalog and provider fixtures
  # ------------------------------------------------------------------------------------------------
  extendedCatalog = agentsLib.models.extendCatalog {
    models = {
      "claude-opus-5-5".channelId.anthropic = "route/claude-opus-5-5";
      "claude-sonnet-5-5".channelId.anthropic = "route/claude-sonnet-5-5";
      "claude-haiku-5-5".channelId.anthropic = "route/claude-haiku-5-5";
      "gemini-4-neon".channelId = {
        a-unused = "unused/gemini-4-neon";
        google = "google/gemini-4-neon";
      };
      "gemini-4-hydrogen".channelId.google = "google/gemini-4-hydrogen";
    };
    defaults.hybrid = {
      default = "gemini-4-neon";
      flagship = "gemini-4-neon";
      standard = "gemini-4-neon";
      mini = "claude-haiku-5-5";
    };
  };

  gatewayProvider = {
    baseUrl = "https://gateway.example.com";
    apiKeyFile = "/run/secrets/default-key";
    clientApiKeyFiles.claude-code = "/run/secrets/claude-key";
    channels = {
      anthropic = {
        family = "claude";
        nativeWebSearch = false;
      };
      google = {
        family = "gemini";
        nativeWebSearch = true;
      };
    };
  };

  resolver = agentsLib.profiles.mkResolver {
    modelCatalog = extendedCatalog;
    providers = {
      gateway = gatewayProvider;
      direct = {
        apiUrls.anthropic-messages = "https://direct.example.com";
        apiKeyFile = "/run/secrets/direct-key";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Profile fixtures
  # ------------------------------------------------------------------------------------------------
  testProfiles = {
    direct-claude = {
      provider = "direct";
      channel = null;
      family = "claude";
      defaultsKey = null;
      proseModel = null;
      nativeWebSearch = false;
      clients = [ "claude-code" ];
    };
    direct-prose = {
      provider = "direct";
      channel = null;
      family = "claude";
      defaultsKey = null;
      proseModel = "gemini-4-neon";
      nativeWebSearch = null;
      clients = null;
    };
    gateway-anthropic = {
      provider = "gateway";
      channel = "anthropic";
      family = "claude";
      defaultsKey = null;
      proseModel = null;
      nativeWebSearch = null;
    };
    gateway-custom-prose = {
      provider = "gateway";
      channel = "anthropic";
      family = "claude";
      proseModel = "gemini-4-hydrogen";
    };
    gateway-unknown-prose = {
      provider = "gateway";
      channel = "anthropic";
      family = "claude";
      proseModel = "nonexistent-model";
    };
    gateway-hybrid = {
      provider = "gateway";
      defaultsKey = "hybrid";
    };
  };

  resolvedClaude = resolver.resolveProfiles {
    profiles = testProfiles;
    nativeFamily = "claude";
    allowedChannels = [
      "anthropic"
      "google"
    ];
    client = "claude-code";
  };

  resolvedAnthropicOnly = resolver.resolveProfiles {
    profiles = testProfiles;
    nativeFamily = "claude";
    allowedChannels = [ "anthropic" ];
    client = "codex";
  };

  resolvedDirectOnly = resolver.resolveProfiles {
    profiles = testProfiles;
    nativeFamily = "claude";
    allowedProviders = [ "direct" ];
    client = "claude-code";
  };
in
check "lib-profiles" [
  {
    name = "injects official profile for nativeFamily";
    ok =
      resolvedClaude ? official
      && resolvedClaude.official.provider == null
      && resolvedClaude.official.nativeWebSearch
      && resolvedClaude.official.roles.default.modelId == "claude-opus-5-5"
      && resolvedClaude.official.roles.plan.effort == "high"
      && resolvedClaude.official.roles.small.modelId == "claude-haiku-5-5"
      && resolvedClaude.official.workloads.prose.modelId == "claude-opus-5-5";
  }
  {
    name = "resolves direct provider without channel rewriting";
    ok =
      resolvedClaude ? direct-claude
      && resolvedClaude.direct-claude.roles.default.modelId == "claude-opus-5-5"
      && resolvedClaude.direct-claude.roles.default.source == "direct-claude"
      && !resolvedClaude.direct-claude.nativeWebSearch;
  }
  {
    name = "handles null-valued optional fields and explicit direct proseModel api";
    ok =
      resolvedClaude ? direct-prose
      && !resolvedClaude.direct-prose.nativeWebSearch
      && resolvedClaude.direct-prose.roles.default.modelId == "claude-opus-5-5"
      && resolvedClaude.direct-prose.workloads.prose.modelId == "gemini-4-neon"
      && resolvedClaude.direct-prose.workloads.prose.api == "openai-chat-completions";
  }
  {
    name = "resolves gateway channel IDs and prose workload with null optional fields";
    ok =
      resolvedClaude ? gateway-anthropic
      && resolvedClaude.gateway-anthropic.roles.default.modelId == "route/claude-opus-5-5"
      && resolvedClaude.gateway-anthropic.roles.default.source == "gateway-anthropic"
      && !resolvedClaude.gateway-anthropic.nativeWebSearch
      && resolvedClaude.gateway-anthropic.workloads.prose.modelId == "google/gemini-4-neon";
  }
  {
    name = "resolves explicit gateway proseModel and falls back when disallowed or unknown";
    ok =
      resolvedClaude.gateway-custom-prose.workloads.prose.modelId == "google/gemini-4-hydrogen"
      && resolvedClaude.gateway-custom-prose.workloads.prose.api == "openai-responses"
      && resolvedAnthropicOnly.gateway-custom-prose.workloads.prose.modelId == "route/claude-opus-5-5"
      && resolvedClaude.gateway-unknown-prose.workloads.prose.modelId == "route/claude-opus-5-5";
  }
  {
    name = "resolves hybrid profile across multi-channel models";
    ok =
      resolvedClaude ? gateway-hybrid
      && resolvedClaude.gateway-hybrid.roles.default.modelId == "google/gemini-4-neon"
      && resolvedClaude.gateway-hybrid.roles.default.channel == "google"
      && resolvedClaude.gateway-hybrid.roles.default.family == "gemini"
      && resolvedClaude.gateway-hybrid.roles.small.modelId == "route/claude-haiku-5-5"
      && resolvedClaude.gateway-hybrid.roles.small.family == "claude"
      && resolvedClaude.gateway-hybrid.nativeWebSearch;
  }
  {
    name = "filters by client, allowedProviders, and allowedChannels";
    ok =
      !(resolvedAnthropicOnly ? direct-claude)
      && !(resolvedAnthropicOnly ? gateway-hybrid)
      && resolvedAnthropicOnly ? gateway-anthropic
      && resolvedAnthropicOnly.gateway-anthropic.workloads.prose.modelId == "route/claude-opus-5-5"
      && resolvedDirectOnly ? official
      && resolvedDirectOnly ? direct-claude
      && !(resolvedDirectOnly ? gateway-anthropic);
  }
  {
    name = "rejects undeclared provider in resolveProfile and resolveProfiles";
    ok =
      throws (
        resolver.resolveProfile {
          name = "missing-provider";
          profile = {
            provider = "undeclared";
            family = "claude";
          };
        }
      )
      && throws (
        resolver.resolveProfiles {
          profiles.missing-provider = {
            provider = "undeclared";
            family = "claude";
          };
        }
      );
  }
  {
    name = "apiKeyFileFor prefers client override";
    ok =
      agentsLib.profiles.apiKeyFileFor gatewayProvider "claude-code" == "/run/secrets/claude-key"
      && agentsLib.profiles.apiKeyFileFor gatewayProvider "codex" == "/run/secrets/default-key"
      && agentsLib.profiles.apiKeyFileFor null "claude-code" == null;
  }
]
