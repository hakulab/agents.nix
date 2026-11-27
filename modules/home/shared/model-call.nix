# ==================================================================================================
# Shared Model Call Builder
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
  scriptsDir,
  modelCallCfg,
}:

{
  assistant,
  timeout ? modelCallCfg.timeouts.modelCall,
}:

let
  json = pkgs.formats.json { };

  tokenFile = modelCallCfg.clientApiKeyFiles.${assistant} or modelCallCfg.apiKeyFile;

  gateway = {
    inherit (modelCallCfg) baseUrl extraHeaders;
    inherit tokenFile;
    caFile = modelCallCfg.caCertFile;
  };

  curlArgs = [
    "-fsSL"

    "--connect-timeout"
    (toString modelCallCfg.timeouts.modelConnect)

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
)
