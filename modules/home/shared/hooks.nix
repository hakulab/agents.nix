# ==================================================================================================
# Shared Hooks
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
  scriptsDir,
  nuModules,
  modelCatalog,
  promptFragments,
  fileFormatter,
  mkModelCall,
  modelCallCfg,
  timeouts,
  dataDir,
  dataHome,
}:

{
  assistant,
  toolClasses,
  enableModelCall ? modelCallCfg.enable,
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Hook command generation
  # ------------------------------------------------------------------------------------------------
  mkNuHook =
    {
      slug,
      script,
      runtimeInputs ? [ ],
      config ? null,
    }:
    let
      name = "${assistant}-${slug}";
    in
    lib.getExe (
      dk.writeNuApplication {
        inherit name;
        text = builtins.readFile script;
        runtimeInputs = [ pkgs.coreutils ] ++ runtimeInputs;
        libDirs = [ nuModules ];
        flags = lib.optionalAttrs (config != null) {
          config = json.generate "${name}.json" config;
        };
      }
    );

  patchInput = lib.getExe (
    dk.writeNuApplication {
      name = "patch-input";
      text = builtins.readFile (scriptsDir + "/lib/patch-input.nu");
    }
  );

  modelCall = mkModelCall {
    inherit assistant;
  };

  commentGateModel =
    if modelCallCfg.commentGateModel != null then
      modelCallCfg.commentGateModel
    else
      let
        key = modelCatalog.defaults.gemini.mini;
        model = modelCatalog.models.${key};
        channels = builtins.attrValues (model.channelId or { });
      in
      if channels != [ ] then lib.head channels else key;

  # ------------------------------------------------------------------------------------------------
  # Hook entries
  # ------------------------------------------------------------------------------------------------
  mkMatcher =
    tools: lib.concatStringsSep "|" (lib.unique (lib.concatMap (tool: toolClasses.${tool}) tools));

  handlerFields = [
    "type"
    "command"
    "prompt"
    "timeout"
    "statusMessage"
    "async"
  ];

  mkEntry =
    hook:
    lib.optionalAttrs (hook ? matcher) { inherit (hook) matcher; }
    // lib.optionalAttrs (hook ? tools) { matcher = mkMatcher hook.tools; }
    // {
      hooks = [ (lib.filterAttrs (name: _: lib.elem name handlerFields) hook) ];
    };

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  # Codex trusts a hook by hashing its event, matcher, and handler, command included. Commands name
  # stable links, which each activation updates, so a rebuild that changes only a script keeps the
  # hook's hash.
  dataPrefix = lib.removePrefix "${dataHome}/" dataDir;

  install =
    requested:
    let
      hooks = lib.filter (hook: (hook.usesModelCall or false) -> enableModelCall) requested;
      commandHooks = lib.filter (hook: hook.type == "command") hooks;
      link = hook: "${dataPrefix}/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
      linked = map (
        hook:
        if hook.type == "command" then
          hook
          // {
            command = "${dataDir}/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
          }
        else
          hook
      ) hooks;
    in
    {
      events = lib.mapAttrs (_: map mkEntry) (lib.groupBy (hook: hook.event) linked);

      dataFiles = lib.listToAttrs (
        map (hook: lib.nameValuePair (link hook) { source = hook.command; }) commandHooks
      );
    };
in
{
  inherit
    install
    mkNuHook
    timeouts
    ;

  hooks = {
    autoFormat = {
      event = "PostToolUse";
      type = "command";
      tools = [ "fileWrite" ];
      timeout = timeouts.postEdit;
      statusMessage = "Formatting edited files";
      command = mkNuHook {
        slug = "auto-format";
        script = scriptsDir + "/hooks/auto-format/auto-format.nu";
        config = {
          inherit fileFormatter patchInput;
        };
      };
    };

    commentGate = {
      event = "PostToolUse";
      type = "command";
      tools = [ "fileWrite" ];
      usesModelCall = true;
      timeout = timeouts.modelCall + timeouts.modelHookMargin;
      statusMessage = "Checking comments";
      command = mkNuHook {
        slug = "comment-gate";
        script = scriptsDir + "/hooks/comment-gate/comment-gate.nu";
        config = {
          inherit modelCall patchInput;
          model = commentGateModel;
          prompt = promptFragments.readPrompt (scriptsDir + "/hooks/comment-gate/prompt.md");
        };
      };
    };

    completeness = {
      event = "Stop";
      type = "prompt";
      timeout = timeouts.modelCall;
      statusMessage = "Checking completeness";
      prompt = builtins.readFile (scriptsDir + "/hooks/completeness/prompt.md");
    };
  };
}
