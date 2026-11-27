# ==================================================================================================
# Providers, Models, and Profiles Evaluation Checks
# ==================================================================================================

{
  lib,
  harness,
}:

let
  inherit (harness) check throws evalHome;

  cfg = evalHome {
    agents = {
      models = {
        catalog = {
          "claude-opus-5-5".channelId.gateway = "gw/claude-opus-5-5";
          "claude-sonnet-5-5".channelId.gateway = "gw/claude-sonnet-5-5";
          "claude-haiku-5-5".channelId.gateway = "gw/claude-haiku-5-5";
          "gemini-4-neon".channelId.google = "google/gemini-4-neon";
        };
        workloadPolicy.claude.flagship = "max";
      };

      providers.my-gateway = {
        baseUrl = "https://gw.example.test";
        apiUrls = {
          anthropic-messages = "https://gw.example.test/anthropic";
          openai-responses = "https://gw.example.test/openai";
        };
        apiKeyFile = "/run/secrets/gw-default";
        clientApiKeyFiles.claude-code = "/run/secrets/gw-claude";
        caCertFile = "/run/secrets/gw-ca.pem";
        extraHeaders."x-tenant" = "demo";
        extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
        channels = {
          gateway = {
            family = "claude";
            nativeWebSearch = false;
          };
          google = {
            family = "gemini";
            nativeWebSearch = false;
          };
        };
      };

      profiles = {
        gw-claude = {
          provider = "my-gateway";
          family = "claude";
          channel = "gateway";
          clients = [ "claude-code" ];
        };

        official-token = {
          provider = null;
          family = "claude";
          oauthTokenFile = "/run/secrets/claude-oauth";
          clients = [ "claude-code" ];
        };
      };
    };
  };

  resolved = cfg.agents.resolved;

  claudeProfiles = resolved.resolveProfiles {
    nativeFamily = "claude";
    client = "claude-code";
  };

  codexProfiles = resolved.resolveProfiles {
    nativeFamily = "gpt";
    client = "codex";
  };

  gwAuth = resolved.anthropicProfiles.mkProfileAuth {
    client = "claude-code";
    caEnvVar = "NODE_EXTRA_CA_CERTS";
  } claudeProfiles.gw-claude;

  oauthAuth = resolved.anthropicProfiles.mkProfileAuth {
    client = "claude-code";
  } claudeProfiles.official-token;

  gwEnvLines = resolved.anthropicProfiles.mkEnvLines {
    label = "claude";
  } gwAuth;

  envVars = resolved.anthropicProfiles.mkProfileEnvVars { } {
    gw = gwAuth;
    oauth = oauthAuth;
  };

  envFileOnlyLines =
    resolved.anthropicProfiles.mkEnvLines
      {
        label = "claude";
      }
      {
        type = "api-key";
        tokenFile = null;
        extraEnvFiles.CUSTOM_SECRET = "/run/secrets/custom-secret";
      };

  pathSecretCfg = evalHome {
    agents.providers.bad-provider.apiKeyFile = /tmp/not-a-string;
  };

  switcher = resolved.mkProfileSwitch {
    name = "test-profile-switch";
    assistant = "test";
    stateDir = "/tmp/test-state";
    extension = "sh";
    profiles = {
      official = "/tmp/official.sh";
      gw-claude = "/tmp/gw-claude.sh";
    };
    defaultProfile = "official";
  };
in
check "home-shared-providers-profiles" [
  # ------------------------------------------------------------------------------------------------
  # Model catalog and workload policy extensions
  # ------------------------------------------------------------------------------------------------
  {
    name = "model catalog merges channelIds while preserving built-in model fields";
    ok =
      resolved.modelCatalog.models."claude-opus-5-5".channelId.gateway == "gw/claude-opus-5-5"
      && resolved.modelCatalog.models."claude-opus-5-5".contextWindow == 1000000;
  }
  {
    name = "workloadPolicy merges custom effort overrides with defaults";
    ok =
      resolved.workloadPolicy.claude.flagship == "max"
      && resolved.workloadPolicy.claude.standard == "medium";
  }

  # ------------------------------------------------------------------------------------------------
  # Profile resolution and client filtering
  # ------------------------------------------------------------------------------------------------
  {
    name = "resolveProfiles includes official plus client-matched custom profiles";
    ok =
      claudeProfiles ? official
      && claudeProfiles ? gw-claude
      && claudeProfiles ? official-token
      && claudeProfiles.gw-claude.workloads.flagship.modelId == "gw/claude-opus-5-5"
      && claudeProfiles.gw-claude.workloads.flagship.effort == "max"
      && claudeProfiles.gw-claude.workloads.prose.modelId == "google/gemini-4-neon";
  }
  {
    name = "client allowlist excludes claude-only profiles from codex";
    ok = codexProfiles ? official && !(codexProfiles ? gw-claude) && !(codexProfiles ? official-token);
  }

  # ------------------------------------------------------------------------------------------------
  # Anthropic profile auth and env script generation
  # ------------------------------------------------------------------------------------------------
  {
    name = "anthropicProfiles resolves per-client API key file, CA cert, headers, and extraEnv";
    ok =
      gwAuth.type == "api-key"
      && gwAuth.baseUrl == "https://gw.example.test/anthropic"
      && gwAuth.tokenFile == "/run/secrets/gw-claude"
      && gwAuth.extraEnv.NODE_EXTRA_CA_CERTS == "/run/secrets/gw-ca.pem"
      && gwAuth.extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER == "0"
      && oauthAuth.type == "oauth-token"
      && oauthAuth.tokenFile == "/run/secrets/claude-oauth";
  }
  {
    name = "mkEnvLines reads token secret at runtime";
    ok = lib.any (line: lib.hasInfix "ANTHROPIC_AUTH_TOKEN" line) gwEnvLines;
  }
  {
    name = "mkEnvLines exports ANTHROPIC_BASE_URL";
    ok = lib.any (
      line:
      lib.hasInfix "ANTHROPIC_BASE_URL=${lib.escapeShellArg "https://gw.example.test/anthropic"}" line
    ) gwEnvLines;
  }
  {
    name = "mkEnvLines exports ANTHROPIC_CUSTOM_HEADERS";
    ok = lib.any (
      line: lib.hasInfix "ANTHROPIC_CUSTOM_HEADERS=${lib.escapeShellArg "x-tenant: demo"}" line
    ) gwEnvLines;
  }
  {
    name = "mkEnvLines exports CA cert path";
    ok = lib.any (
      line: lib.hasInfix "NODE_EXTRA_CA_CERTS=${lib.escapeShellArg "/run/secrets/gw-ca.pem"}" line
    ) gwEnvLines;
  }
  {
    name = "mkEnvLines supports extraEnvFiles when tokenFile is null";
    ok =
      lib.any (line: lib.hasInfix "__read_secret()" line) envFileOnlyLines
      && lib.any (line: lib.hasInfix "CUSTOM_SECRET=" line) envFileOnlyLines
      && !(lib.any (line: lib.hasInfix "ANTHROPIC_AUTH_TOKEN" line) envFileOnlyLines);
  }
  {
    name = "secret *File options reject Nix path literals to prevent store copying";
    ok = throws pathSecretCfg.agents.providers.bad-provider.apiKeyFile;
  }
  {
    name = "mkProfileEnvVars tracks static and extra profile env vars for cleanup";
    ok =
      lib.elem "ANTHROPIC_AUTH_TOKEN" envVars
      && lib.elem "NODE_EXTRA_CA_CERTS" envVars
      && lib.elem "CLAUDE_CODE_ATTRIBUTION_HEADER" envVars;
  }

  # ------------------------------------------------------------------------------------------------
  # Profile switcher helper
  # ------------------------------------------------------------------------------------------------
  {
    name = "mkProfileSwitch builds package, profile files, and valid assertion";
    ok =
      switcher.assertion.assertion
      && switcher.files ? "/tmp/test-state/profiles/official.sh"
      && lib.hasSuffix "/bin/test-profile-switch" (lib.getExe switcher.package);
  }
]
