# ==================================================================================================
# Shared Model Call Module (agents.modelCall)
# ==================================================================================================

{
  devkitLib,
  scriptsDir,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.modelCall;
  dk = devkitLib.mkLib pkgs;
  json = pkgs.formats.json { };

  providerCfg =
    if cfg.provider != null then config.agents.providers.${cfg.provider} or null else null;

  # ------------------------------------------------------------------------------------------------
  # Model call builder
  # ------------------------------------------------------------------------------------------------
  mkModelCall =
    {
      assistant,
      timeout ? cfg.timeouts.modelCall,
    }:
    let
      tokenFile = cfg.clientApiKeyFiles.${assistant} or cfg.apiKeyFile;

      gateway = {
        inherit (cfg) baseUrl extraHeaders;
        inherit tokenFile;
        caFile = cfg.caCertFile;
      };

      curlArgs = [
        "-fsSL"

        "--connect-timeout"
        (toString cfg.timeouts.modelConnect)

        "--max-time"
        (toString timeout)
      ];

      configFile = json.generate "${assistant}-model-call.json" {
        inherit gateway curlArgs;
        curl = lib.getExe pkgs.curl;
      };
    in
    lib.getExe (
      dk.writeNuApplication {
        name = "${assistant}-model-call";
        text = builtins.readFile (scriptsDir + "/shared/model-call/model-call.nu");
        runtimeInputs = [ pkgs.coreutils ];
        flags.config = configFile;
      }
    );
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.modelCall = {
    enable = lib.mkEnableOption "OpenAI-compatible model call endpoint for LLM-backed hooks and skills";

    provider = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Provider name from agents.providers to inherit endpoint, credentials, and channels from";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if providerCfg != null then providerCfg.baseUrl else null;
      defaultText = lib.literalExpression "agents.providers.<provider>.baseUrl or null";
      description = "OpenAI-compatible base URL with an optional trailing /v1";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if providerCfg != null then providerCfg.apiKeyFile else null;
      defaultText = lib.literalExpression "agents.providers.<provider>.apiKeyFile or null";
      description = "Runtime file path containing the default API key for model calls";
    };

    clientApiKeyFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Per-caller runtime API key file paths overriding apiKeyFile";
    };

    caCertFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if providerCfg != null then providerCfg.caCertFile else null;
      defaultText = lib.literalExpression "agents.providers.<provider>.caCertFile or null";
      description = "Runtime file path to a custom CA certificate bundle for model calls";
    };

    channels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = if providerCfg != null then builtins.attrNames providerCfg.channels else [ ];
      defaultText = lib.literalExpression "builtins.attrNames (agents.providers.<provider>.channels or { })";
      description = "Preferred provider channel names used when resolving model IDs";
    };

    extraHeaders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra HTTP headers included in model call requests";
    };

    timeouts = {
      modelConnect = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "TCP connection timeout in seconds for model calls";
      };

      modelCall = lib.mkOption {
        type = lib.types.int;
        default = 90;
        description = "Default request timeout in seconds for model calls";
      };
    };

    mkCall = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      readOnly = true;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      # --------------------------------------------------------------------------------------------
      # Assertions
      # --------------------------------------------------------------------------------------------
      assertions = [
        {
          assertion = cfg.provider == null || config.agents.providers ? ${cfg.provider};
          message = "agents.modelCall.provider references undeclared provider '${toString cfg.provider}'";
        }
        {
          assertion = cfg.enable -> cfg.baseUrl != null;
          message = "agents.modelCall.baseUrl must be set when agents.modelCall.enable is true";
        }
      ];

      # --------------------------------------------------------------------------------------------
      # Internal exports
      # --------------------------------------------------------------------------------------------
      agents.modelCall.mkCall = mkModelCall;
    }

    (lib.mkIf (providerCfg != null) {
      agents.modelCall = {
        clientApiKeyFiles = lib.mapAttrs (_: lib.mkOptionDefault) providerCfg.clientApiKeyFiles;
        extraHeaders = lib.mapAttrs (_: lib.mkOptionDefault) providerCfg.extraHeaders;
      };
    })
  ];
}
