# ==================================================================================================
# Claude Code Home Manager Checks
# ==================================================================================================

{
  pkgs,
  lib,
  nushell,
  harness,
  homeModules,
}:

let
  fixtures = import ./fixtures.nix { inherit pkgs harness homeModules; };
in
{
  home-claude-code = import ./eval.nix { inherit lib harness fixtures; };

  home-claude-code-artifacts = import ./artifacts.nix {
    inherit
      pkgs
      nushell
      harness
      fixtures
      ;
  };
}
