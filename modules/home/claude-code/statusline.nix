# ==================================================================================================
# Claude Code Statusline
# ==================================================================================================

{
  lib,
  resolved,
  statuslineCfg,
}:

let
  defaultModels = lib.concatMapAttrs (
    id: model: lib.genAttrs ([ id ] ++ builtins.attrValues (model.channelId or { })) (_: model.name)
  ) resolved.modelCatalog.models;

  models = defaultModels // statuslineCfg.models;

  baseSettings = {
    inherit models;
  }
  // lib.optionalAttrs (statuslineCfg.costSources != [ ]) {
    cost_sources = statuslineCfg.costSources;
  };

  settings = lib.recursiveUpdate baseSettings statuslineCfg.extraSettings;
in
{
  enable = true;
  inherit (statuslineCfg) package;
  inherit settings;
}
