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
  modelOverride,
  timeouts,
}:

let
  commentGateModel =
    if modelOverride != null then
      modelOverride
    else
      modelIdFor modelCatalog modelCatalog.defaults.gemini.mini;
in
{
  event = "PostToolUse";
  type = "command";
  tools = [ "fileWrite" ];
  usesModelCall = true;
  timeout = timeouts.modelCall + timeouts.modelMargin;
  statusMessage = "Checking comments";
  command = mkNuHook {
    slug = "comment-gate";
    script = scriptsDir + "/shared/hooks/comment-gate/comment-gate.nu";
    config = {
      inherit modelCall patchInput;
      model = commentGateModel;
      prompt = promptFragments.readPrompt (scriptsDir + "/shared/hooks/comment-gate/prompt.md");
    };
  };
}
