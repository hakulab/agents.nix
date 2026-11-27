# ==================================================================================================
# Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  home-manager,
  homeModules,
  darwinPkgs,
}:

let
  baseHarness = import ../lib.nix { inherit pkgs lib; };

  homeDirectory = if pkgs.stdenv.isDarwin then "/Users/tester" else "/home/tester";

  evalModulesWith =
    {
      evalPkgs ? pkgs,
      evalHomeDirectory ? if evalPkgs.stdenv.isDarwin then "/Users/tester" else "/home/tester",
      modules,
    }:
    (home-manager.lib.homeManagerConfiguration {
      pkgs = evalPkgs;
      modules = [
        {
          home = {
            username = "tester";
            homeDirectory = evalHomeDirectory;
            stateVersion = "26.05";
          };
        }
      ]
      ++ modules;
    }).config;

  evalModules = modules: evalModulesWith { inherit modules; };

  evalHomeWith = modules: extraModule: evalModules (modules ++ [ extraModule ]);

  evalHome = evalHomeWith [ homeModules.shared ];

  harness = baseHarness // {
    inherit
      homeDirectory
      evalModulesWith
      evalModules
      evalHomeWith
      evalHome
      ;
  };

  claudeCodeChecks = import ./claude-code.nix {
    inherit
      pkgs
      lib
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

  home-codex = import ./codex.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  home-omp = import ./omp.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  home-oxide-code = import ./oxide-code.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      ;
  };

  home-peripheral-tools = import ./tools.nix {
    inherit
      pkgs
      lib
      harness
      homeModules
      darwinPkgs
      ;
  };
}
// claudeCodeChecks
