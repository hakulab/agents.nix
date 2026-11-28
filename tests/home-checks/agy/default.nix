# ==================================================================================================
# Antigravity CLI Home Manager Checks
# ==================================================================================================

{
  pkgs,
  lib,
  nushell,
  harness,
  homeModules,
}:

let
  fixtures = import ./fixtures.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };
in
{
  home-agy = import ./eval.nix { inherit lib harness fixtures; };

  home-agy-artifacts = import ./artifacts.nix { inherit pkgs nushell fixtures; };
}
