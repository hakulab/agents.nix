# ==================================================================================================
# Context7 CLI Module (agents.ctx7)
# ==================================================================================================

{
  nixpkgs-unstable,
  agentsLib,
  sharedModule,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.ctx7;
  unstablePackages = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  ctx7Pkg =
    if cfg.apiKeyFile != null then
      agentsLib.wrapPackage {
        inherit pkgs;
        pkg = cfg.package;
        envFiles.CONTEXT7_API_KEY = cfg.apiKeyFile;
      }
    else
      cfg.package;
in
{
  imports = [ sharedModule ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.ctx7 = {
    enable = lib.mkEnableOption "Context7 CLI (ctx7)";

    package = lib.mkOption {
      type = lib.types.package;
      default = unstablePackages.ctx7;
      description = "Package providing the ctx7 CLI";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file path containing the Context7 API key";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home.packages = [ ctx7Pkg ];
  };
}
