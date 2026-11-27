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

  # ------------------------------------------------------------------------------------------------
  # Model ID resolution and model call builder
  # ------------------------------------------------------------------------------------------------
  modelIdFor =
    modelCatalog: key:
    let
      model = modelCatalog.models.${key} or { };
      channelIds = model.channelId or { };
      selected = lib.filter (ch: channelIds ? ${ch}) cfg.channels;
      allChannels = builtins.attrValues channelIds;
    in
    if selected != [ ] then
      channelIds.${lib.head selected}
    else if allChannels != [ ] then
      lib.head allChannels
    else
      key;

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
        text = builtins.readFile (scriptsDir + "/lib/model-call.nu");
        runtimeInputs = [ pkgs.coreutils ];
        flags.config = configFile;
      }
    );
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    modelCall = {
      enable = lib.mkEnableOption "OpenAI-compatible model call endpoint for LLM-backed hooks and skills";

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Base URL of the OpenAI-compatible chat completions endpoint";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing the default API key for model calls";
      };

      clientApiKeyFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-caller runtime API key file paths overriding apiKeyFile";
      };

      caCertFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path to a custom CA certificate bundle for model calls";
      };

      channels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Preferred provider channel names used when resolving model IDs";
      };

      extraHeaders = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra HTTP headers included in model call requests";
      };

      commentGateModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override model ID used by the comment-gate hook";
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

        modelHookMargin = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Extra seconds a hook outlives its model call so timeouts can be reported";
        };
      };
    };

    _internal = {
      mkModelCall = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      modelIdFor = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = {
    agents._internal = {
      inherit mkModelCall modelIdFor;
    };

    assertions = [
      {
        assertion = cfg.enable -> cfg.baseUrl != null;
        message = "agents.modelCall.baseUrl must be set when agents.modelCall.enable is true";
      }
    ];
  };
}
