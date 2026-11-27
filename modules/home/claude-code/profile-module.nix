# ==================================================================================================
# Claude Code Profile Override Submodule
# ==================================================================================================

{
  lib,
}:

lib.types.submodule {
  options = {
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables merged into this profile";
    };

    extraHeaders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional HTTP headers merged into this profile's API requests";
    };

    nativeWebSearch = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Override whether native WebSearch is exposed for this profile";
    };

    sessionEffort = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override reasoning effort for the main session";
    };

    modelEfforts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Per-model reasoning effort overrides merged into this profile";
    };

    compactWindows = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.positive;
      default = { };
      description = "Per-model auto-compaction window overrides in tokens";
    };

    modelOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Anthropic model ID to provider model ID overrides merged into this profile";
    };
  };
}
