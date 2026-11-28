# ==================================================================================================
# Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  nushell,
  home-manager,
  homeModules,
  mkCodexModelCatalog,
  darwinPkgs,
}:

let
  harness = import ./harness.nix {
    inherit
      pkgs
      lib
      home-manager
      homeModules
      ;
  };

  claudeCodeChecks = import ./claude-code {
    inherit
      pkgs
      lib
      nushell
      harness
      homeModules
      ;
  };

  agyChecks = import ./agy {
    inherit
      pkgs
      lib
      nushell
      harness
      homeModules
      ;
  };
in
{
  home-default = import ./bundle.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  home-shared-defaults = import ./defaults.nix {
    inherit pkgs lib harness;
  };

  home-shared-providers-profiles = import ./providers-profiles.nix {
    inherit lib harness;
  };

  home-shared-mcp = import ./mcp.nix {
    inherit pkgs lib harness;
  };

  home-shared-hooks-skills = import ./hooks-skills.nix {
    inherit pkgs lib harness;
  };

  inherit (claudeCodeChecks) home-claude-code home-claude-code-artifacts;

  home-codex = import ./codex {
    inherit
      pkgs
      lib
      harness
      homeModules
      mkCodexModelCatalog
      ;
  };

  home-omp = import ./omp {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  inherit (agyChecks) home-agy home-agy-artifacts;

  home-oxide-code = import ./oxide-code {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  home-peripheral-tools = import ./tools {
    inherit
      pkgs
      lib
      harness
      homeModules
      darwinPkgs
      ;
  };
}
