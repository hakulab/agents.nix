# ==================================================================================================
# Pure Library Checks
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
}:

let
  check =
    name: assertions:
    let
      failed = lib.filter (item: !item.ok) assertions;
      message = lib.concatMapStringsSep "\n" (item: "  - ${item.name}") failed;
    in
    if failed != [ ] then
      throw "check `${name}` failed:\n${message}"
    else
      pkgs.runCommand "check-${name}" { } ''
        touch "$out"
      '';

  throws = expr: !(builtins.tryEval (builtins.deepSeq expr true)).success;

  # ------------------------------------------------------------------------------------------------
  # Permissions validation
  # ------------------------------------------------------------------------------------------------
  defaultPolicy = agentsLib.permissions.defaultPolicy;

  customPolicy = agentsLib.permissions.mkPolicy {
    ownRepositories = [ "github.com/example" ];
    serverDisplayNames = agentsLib.mcp.presetDisplayNames // {
      custom = "Custom";
    };
    extraAllowCommands.readOnly = [ "example-status" ];
    extraGateCommands = [
      {
        command = "example-deploy";
        reason = "Deploys production services.";
      }
    ];
    extraMcpAllows.custom = [ "read_item" ];
    extraMcpGates.custom = [
      {
        tool = "delete_item";
        reason = "Deletes remote items.";
      }
    ];
  };

  permissionsCheck = check "lib-permissions" [
    {
      name = "default policy evaluates cleanly";
      ok =
        builtins.length defaultPolicy.allowCommands > 0
        && builtins.length defaultPolicy.gateCommands > 0
        && builtins.length defaultPolicy.mcpAllows > 0
        && builtins.length defaultPolicy.mcpGates > 0;
    }
    {
      name = "custom policy extends commands and MCP servers";
      ok =
        lib.elem "example-status" customPolicy.allowCommands
        && lib.elem "example-deploy" customPolicy.gateCommands
        && lib.any (entry: entry.server == "custom" && entry.tool == "read_item") customPolicy.mcpAllows
        && lib.any (entry: entry.server == "custom" && entry.tool == "delete_item") customPolicy.mcpGates;
    }
    {
      name = "rejects allow overlapping gate";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraAllowCommands.readOnly = [ "sudo ls" ];
        }
      );
    }
    {
      name = "rejects readOnly covering mutating";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraAllowCommands.mutating = [ "ls -la" ];
        }
      );
    }
    {
      name = "rejects duplicate command";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraAllowCommands.readOnly = [ "ls" ];
        }
      );
    }
    {
      name = "rejects wildcard command";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraAllowCommands.readOnly = [ "git *" ];
        }
      );
    }
    {
      name = "rejects unknown MCP server";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraMcpAllows.unknownServer = [ "list_things" ];
        }
      );
    }
    {
      name = "rejects MCP tool both allowed and gated";
      ok = throws (
        agentsLib.permissions.mkPolicy {
          extraMcpAllows.github = [ "merge_pull_request" ];
        }
      );
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Profile resolution
  # ------------------------------------------------------------------------------------------------
  extendedCatalog = agentsLib.models.extendCatalog {
    defaults.hybrid = {
      default = "gemini-4-neon";
      flagship = "gemini-4-neon";
      standard = "gemini-4-neon";
      mini = "claude-haiku-5-5";
    };
    models = {
      "claude-opus-5-5".channelId.anthropic = "route/claude-opus-5-5";
      "claude-sonnet-5-5".channelId.anthropic = "route/claude-sonnet-5-5";
      "claude-haiku-5-5".channelId.anthropic = "route/claude-haiku-5-5";
      "gemini-4-neon".channelId.google = "google/gemini-4-neon";
      "gemini-4-hydrogen".channelId.google = "google/gemini-4-hydrogen";
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

  testProfiles = {
    direct-claude = {
      provider = "direct";
      channel = null;
      family = "claude";
      nativeWebSearch = false;
      clients = [ "claude-code" ];
    };
    gateway-anthropic = {
      provider = "gateway";
      channel = "anthropic";
      family = "claude";
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

  profilesCheck = check "lib-profiles" [
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
      name = "resolves gateway channel IDs and prose workload";
      ok =
        resolvedClaude ? gateway-anthropic
        && resolvedClaude.gateway-anthropic.roles.default.modelId == "route/claude-opus-5-5"
        && resolvedClaude.gateway-anthropic.roles.default.source == "gateway-anthropic"
        && !resolvedClaude.gateway-anthropic.nativeWebSearch
        && resolvedClaude.gateway-anthropic.workloads.prose.modelId == "google/gemini-4-neon";
    }
    {
      name = "resolves hybrid profile across channels";
      ok =
        resolvedClaude ? gateway-hybrid
        && resolvedClaude.gateway-hybrid.roles.default.modelId == "google/gemini-4-neon"
        && resolvedClaude.gateway-hybrid.roles.default.family == "gemini"
        && resolvedClaude.gateway-hybrid.roles.small.modelId == "route/claude-haiku-5-5"
        && resolvedClaude.gateway-hybrid.roles.small.family == "claude"
        && resolvedClaude.gateway-hybrid.nativeWebSearch;
    }
    {
      name = "filters by client and allowedChannels and falls back prose to flagship";
      ok =
        !(resolvedAnthropicOnly ? direct-claude)
        && !(resolvedAnthropicOnly ? gateway-hybrid)
        && resolvedAnthropicOnly ? gateway-anthropic
        && resolvedAnthropicOnly.gateway-anthropic.workloads.prose.modelId == "route/claude-opus-5-5";
    }
    {
      name = "apiKeyFileFor prefers client override";
      ok =
        agentsLib.profiles.apiKeyFileFor gatewayProvider "claude-code" == "/run/secrets/claude-key"
        && agentsLib.profiles.apiKeyFileFor gatewayProvider "codex" == "/run/secrets/default-key"
        && agentsLib.profiles.apiKeyFileFor null "claude-code" == null;
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Supporting helpers
  # ------------------------------------------------------------------------------------------------
  helpersCheck = check "lib-helpers" [
    {
      name = "channelIds strips route prefix";
      ok =
        agentsLib.models.channelIds "route/claude-opus-5-5" == [
          "route/claude-opus-5-5"
          "claude-opus-5-5"
        ]
        && agentsLib.models.channelIds "claude-opus-5-5" == [ "claude-opus-5-5" ];
    }
    {
      name = "prompts renderText and joinSections";
      ok =
        agentsLib.prompts.renderText { "@who@" = "world"; } "hello @who@" == "hello world"
        &&
          agentsLib.prompts.joinSections [
            "a"
            ""
            "  b  "
          ] == "a\n\nb";
    }
    {
      name = "proxy renderNoProxy deduplicates entries";
      ok =
        agentsLib.proxy.renderNoProxy {
          noProxy = [
            "example.com"
            "localhost"
          ];
        } == "localhost,127.0.0.1,10.0.0.0/8,example.com";
    }
    {
      name = "mcp computeEnabledServers subtracts disabledServers";
      ok =
        agentsLib.mcp.computeEnabledServers {
          enabledServers = [
            "github"
            "gitlab"
          ];
          disabledServers = [ "gitlab" ];
        } == [ "github" ];
    }
  ];
in
{
  lib-helpers = helpersCheck;
  lib-permissions = permissionsCheck;
  lib-profiles = profilesCheck;
}
