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

  settings = {
    inherit models;
  }
  // lib.optionalAttrs (statuslineCfg.costSources != [ ]) {
    cost_sources = statuslineCfg.costSources;
  }
  // statuslineCfg.extraSettings;
in
{
  inherit (statuslineCfg) enable package;
  inherit settings;
}
