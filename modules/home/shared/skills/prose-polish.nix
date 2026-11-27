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
  internal,
  modelCall,
  modelOverride,
}:

let
  inherit (internal) modelCatalog modelIdFor promptFragments;
  json = pkgs.formats.json { };

  skillDir = assetsDir + "/skills/prose-polish";
  skillScript = "scripts/prose-polish";

  models = lib.mapAttrs (key: _: modelIdFor modelCatalog key) modelCatalog.models;

  proseModelKey = modelCatalog.defaults.prose;

  skillConfig = json.generate "prose-polish.json" {
    inherit
      models
      modelCall
      ;
    inherit (promptFragments) phrasing;
    maxRepairs = 3;
    model = if modelOverride != null then modelOverride else models.${proseModelKey} or proseModelKey;
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
