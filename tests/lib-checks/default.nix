# ==================================================================================================
# Pure Library Checks
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
}:

let
  inherit (import ../lib.nix { inherit pkgs lib; }) check throws;

  evalOptionSet =
    options: cfg:
    (lib.evalModules {
      modules = [
        { inherit options; }
        cfg
      ];
    }).config;
in
{
  lib-helpers = import ./helpers.nix {
    inherit
      lib
      agentsLib
      check
      throws
      evalOptionSet
      ;
  };

  lib-permissions = import ./permissions.nix {
    inherit
      lib
      agentsLib
      check
      throws
      ;
  };

  lib-profiles = import ./profiles.nix {
    inherit
      agentsLib
      check
      throws
      ;
  };

  lib-wrap-package = import ./wrap-package.nix {
    inherit
      pkgs
      lib
      agentsLib
      ;
  };
}
