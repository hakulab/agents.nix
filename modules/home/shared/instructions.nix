# ==================================================================================================
# Shared Prompt Fragments and Instruction Documents
# ==================================================================================================

{
  agentsLib,
  assetsDir,
}:

let
  fragmentsDir = assetsDir + "/prompt-fragments";
  instructionsDir = assetsDir + "/instructions";
  docsDir = instructionsDir + "/docs";

  renderer = agentsLib.prompts.mkPromptRenderer {
    "@comments@\n" = fragmentsDir + "/comments.md";
    "@phrasing@\n" = fragmentsDir + "/phrasing.md";
    "@proseTics@\n" = fragmentsDir + "/prose-tics.md";
    "@readOnly@\n" = fragmentsDir + "/read-only.md";
  };

  promptFragments = {
    inherit (renderer) fragments renderPrompt readPrompt;
    phrasing = renderer.fragments."@phrasing@\n";
    roleSections = {
      preamble = builtins.readFile (fragmentsDir + "/preamble.md");
      memory = builtins.readFile (fragmentsDir + "/memory.md");
      coordination = builtins.readFile (fragmentsDir + "/coordination.md");
      status = builtins.readFile (fragmentsDir + "/status.md");
    };
  };

  defaultDocs = {
    "code-design.md" = promptFragments.readPrompt (docsDir + "/code-design.md");
    "delegation.md" = promptFragments.readPrompt (docsDir + "/delegation.md");
    "documentation.md" = promptFragments.readPrompt (docsDir + "/documentation.md");
    "editing-and-comments.md" = promptFragments.readPrompt (docsDir + "/editing-and-comments.md");
    "mcp-servers.md" = promptFragments.readPrompt (docsDir + "/mcp-servers.md");
    "terminals-and-workmux.md" = promptFragments.readPrompt (docsDir + "/terminals-and-workmux.md");
    "verification-and-tests.md" = promptFragments.readPrompt (docsDir + "/verification-and-tests.md");
    "writing.md" = promptFragments.readPrompt (docsDir + "/writing.md");
  };

  renderBase =
    substitutions: promptFragments.renderPrompt substitutions (instructionsDir + "/instructions.md");
in
{
  inherit
    defaultDocs
    promptFragments
    renderBase
    ;
}
