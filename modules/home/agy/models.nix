# ==================================================================================================
# Antigravity CLI Model Workloads
# ==================================================================================================

{
  lib,
  resolved,
}:

let
  inherit
    (resolved.resolveProfiles {
      profiles = { };
      nativeFamily = "gemini";
    })
    official
    ;

  inherit (official) workloads;
  inherit (official.roles) default;
  miniModel = workloads.mini.modelKey;
  flagshipModel = workloads.flagship.modelKey;
in
{
  defaultSlug =
    default.modelId
    + lib.optionalString ((default.model.thinking.mode or null) == "effort") "-${default.effort}";

  # Custom agents accept tier aliases. Keep inheritance when neither tier is a distinct match.
  tierFor =
    workload:
    let
      inherit (workloads.${workload}) modelKey;
    in
    if modelKey == default.modelKey || miniModel == flagshipModel then
      "inherit"
    else if modelKey == miniModel then
      "flash"
    else if modelKey == flagshipModel then
      "pro"
    else
      "inherit";
}
