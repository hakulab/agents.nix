# ==================================================================================================
# Prose Polish Skill
# ==================================================================================================
# Builds the installed prose-polish skill directory: its instructions, agent metadata, and
# evaluation reference, plus the wrapper that carries the model call and prompts. Tests and stubs
# stay out of the installed directory.
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
  assetsDir,
  modelCatalog,
  promptFragments,
  modelCall,
}:

let
  json = pkgs.formats.json { };

  skillDir = assetsDir + "/skills/prose-polish";
  skillScript = "scripts/prose-polish";

  modelIdFor =
    key: model:
    let
      channels = builtins.attrValues (model.channelId or { });
    in
    if channels != [ ] then lib.head channels else key;

  models = lib.mapAttrs modelIdFor modelCatalog.models;

  proseModelKey = modelCatalog.defaults.prose;

  skillConfig = json.generate "prose-polish.json" {
    inherit
      models
      modelCall
      ;
    inherit (promptFragments) phrasing;
    maxRepairs = 3;
    model = models.${proseModelKey} or proseModelKey;
    prompt = builtins.readFile (skillDir + "/scripts/prompt.md");
    repairPrompt = builtins.readFile (skillDir + "/scripts/repair-prompt.md");
  };

  command = dk.writeNuApplication {
    name = "prose-polish";
    text = builtins.readFile (skillDir + "/scripts/prose-polish.nu");
    runtimeInputs = [ pkgs.coreutils ];
    flags.config = skillConfig;
  };

  src = lib.fileset.toSource {
    root = skillDir;
    fileset = lib.fileset.unions [
      (skillDir + "/SKILL.md")
      (skillDir + "/agents")
      (skillDir + "/references")
    ];
  };
in
pkgs.runCommand "prose-polish-skill" { passthru.scripts = [ skillScript ]; } ''
  cp -r --no-preserve=mode ${src} "$out"
  install -Dm0755 ${lib.getExe command} "$out/${skillScript}"
''
