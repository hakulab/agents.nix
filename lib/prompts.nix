# ==================================================================================================
# Prompt Rendering and Composition
# ==================================================================================================

{
  lib,
}:

let
  renderText =
    substitutions: text:
    builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions) text;

  renderFile = substitutions: file: renderText substitutions (builtins.readFile file);

  mkPromptRenderer =
    fragments:
    let
      loaded = builtins.mapAttrs (
        _: value: if builtins.isPath value then builtins.readFile value else value
      ) fragments;
    in
    {
      fragments = loaded;
      renderPrompt = extra: file: renderFile (loaded // extra) file;
      readPrompt = file: renderFile loaded file;
    };

  joinSections =
    sections: lib.concatStringsSep "\n\n" (lib.filter (section: section != "") (map lib.trim sections));
in
{
  inherit
    joinSections
    mkPromptRenderer
    renderFile
    renderText
    ;
}
