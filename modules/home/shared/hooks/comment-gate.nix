# ==================================================================================================
# Comment-Gate Hook
# ==================================================================================================

{
  scriptsDir,
  mkNuHook,
  modelCall,
  patchInput,
  modelCatalog,
  modelIdFor,
  promptFragments,
  modelCallCfg,
  timeouts,
}:

let
  commentGateModel =
    if modelCallCfg.commentGateModel != null then
      modelCallCfg.commentGateModel
    else
      modelIdFor modelCatalog modelCatalog.defaults.gemini.mini;
in
{
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
}
