# ==================================================================================================
# Pure Library Checks
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
}:

let
  harness = import ../lib.nix { inherit pkgs lib; };

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
      harness
      evalOptionSet
      ;
  };

  lib-permissions = import ./permissions.nix {
    inherit
      lib
      agentsLib
      harness
      ;
  };

  lib-profiles = import ./profiles.nix {
    inherit
      agentsLib
      harness
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
