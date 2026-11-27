# ==================================================================================================
# Default Model Catalog and Workload Policy
# ==================================================================================================

{
  lib,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Family capabilities
  # ------------------------------------------------------------------------------------------------
  claudeCommon = {
    vendor = "anthropic";
    apis = [ "anthropic-messages" ];

    contextWindow = 1000000;
    maxTokens = 128000;
    autoCompactTokens = 400000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "anthropic-adaptive";
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
      defaultLevel = "medium";
    };
  };

  gptCommon = {
    vendor = "openai";
    apis = [ "openai-responses" ];

    contextWindow = 1050000;
    maxTokens = 128000;
    autoCompactTokens = 272000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "effort";
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
      defaultLevel = "high";
    };
  };

  geminiCommon = {
    vendor = "google";
    apis = [
      "openai-chat-completions"
      "openai-responses"
    ];

    contextWindow = 1048576;
    maxTokens = 65536;
    autoCompactTokens = 400000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "effort";
      efforts = [
        "low"
        "medium"
        "high"
      ];
      defaultLevel = "medium";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Default catalog
  # ------------------------------------------------------------------------------------------------
  familyDefaults = {
    claude = {
      default = "claude-opus-5-5";
      flagship = "claude-opus-5-5";
      standard = "claude-sonnet-5-5";
      mini = "claude-haiku-5-5";
    };

    gpt = {
      default = "gpt-6.2-sol";
      flagship = "gpt-6.2-astra";
      standard = "gpt-6.2-sol";
      mini = "gpt-6-luna";
    };

    gemini = {
      default = "gemini-4-neon";
      flagship = "gemini-4-neon";
      standard = "gemini-4-neon";
      mini = "gemini-4-hydrogen";
    };
  };

  defaultCatalog = {
    defaults = familyDefaults // {
      prose = "gemini-4-neon";
    };

    models = {
      # --------------------------------------------------------------------------------------------
      # Claude
      # --------------------------------------------------------------------------------------------
      "claude-opus-5-5" = claudeCommon // {
        name = "Claude Opus 5.5";
      };

      "claude-sonnet-5-5" = claudeCommon // {
        name = "Claude Sonnet 5.5";
      };

      "claude-haiku-5-5" = claudeCommon // {
        name = "Claude Haiku 5.5";
      };

      # --------------------------------------------------------------------------------------------
      # GPT
      # --------------------------------------------------------------------------------------------
      "gpt-6.2-astra" = gptCommon // {
        name = "GPT-6.2 Astra";
      };

      "gpt-6.2-sol" = gptCommon // {
        name = "GPT-6.2 Sol";
      };

      "gpt-6.1-terra" = gptCommon // {
        name = "GPT-6.1 Terra";
        contextWindow = 922000;
      };

      "gpt-6-luna" = gptCommon // {
        name = "GPT-6 Luna";

        thinking = gptCommon.thinking // {
          defaultLevel = "low";
        };
      };

      # --------------------------------------------------------------------------------------------
      # Gemini
      # --------------------------------------------------------------------------------------------
      "gemini-4-carbon" = geminiCommon // {
        name = "Gemini 4 Carbon";
      };

      "gemini-4-neon" = geminiCommon // {
        name = "Gemini 4 Neon";
      };

      "gemini-4-hydrogen" = geminiCommon // {
        name = "Gemini 4 Hydrogen";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Workload policy
  # ------------------------------------------------------------------------------------------------
  workloadPolicy = {
    claude = {
      default = "medium";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };

    gpt = {
      default = "medium";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };

    gemini = {
      default = "low";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };
  };

  roleTiers = {
    default = {
      modelTier = "default";
      effortTier = "default";
    };

    plan = {
      modelTier = "flagship";
      effortTier = "flagship";
    };

    task = {
      modelTier = "standard";
      effortTier = "standard";
    };

    small = {
      modelTier = "mini";
      effortTier = "mini";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Family metadata and helpers
  # ------------------------------------------------------------------------------------------------
  familyApis = {
    claude = "anthropic-messages";
    gpt = "openai-responses";
    gemini = "openai-responses";
  };

  modelAliases = {
    claude = {
      flagship = "opus";
      standard = "sonnet";
      mini = "haiku";
    };
  };

  # Runtime transcripts may record either the `<route>/<id>` channel ID or the route-stripped ID.
  channelIds =
    channelId:
    let
      stripped = builtins.match "[^/]+/(.+)" channelId;
    in
    lib.unique ([ channelId ] ++ lib.optional (stripped != null) (builtins.head stripped));

  extendCatalog =
    {
      base ? defaultCatalog,
      models ? { },
      defaults ? { },
    }:
    {
      defaults = lib.recursiveUpdate base.defaults defaults;
      models = lib.recursiveUpdate base.models models;
    };
in
{
  inherit
    defaultCatalog
    workloadPolicy
    roleTiers
    familyApis
    modelAliases
    channelIds
    extendCatalog
    ;
}
