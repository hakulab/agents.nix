# ==================================================================================================
# Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  home-manager,
  sharedModule,
  claudeCodeModule,
  codexModule,
  ompModule,
  oxideCodeModule,
}:

let
  inherit (import ../lib.nix { inherit pkgs lib; }) check throws;

  homeDirectory = if pkgs.stdenv.isDarwin then "/Users/tester" else "/home/tester";

  evalModules =
    modules:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home = {
            username = "tester";
            inherit homeDirectory;
            stateVersion = "26.05";
          };
        }
      ]
      ++ modules;
    }).config;

  evalHomeWith = modules: extraModule: evalModules (modules ++ [ extraModule ]);

  evalHome = evalHomeWith [ sharedModule ];

  claudeCodeChecks = import ./claude-code.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalHomeWith
      sharedModule
      claudeCodeModule
      homeDirectory
      ;
  };
in
{
  home-codex = import ./codex.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalModules
      codexModule
      sharedModule
      homeDirectory
      ;
  };

  home-shared-defaults = import ./defaults.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalHome
      homeDirectory
      ;
  };

  home-shared-providers-profiles = import ./providers-profiles.nix {
    inherit
      lib
      check
      throws
      evalHome
      ;
  };

  home-shared-mcp = import ./mcp.nix {
    inherit
      lib
      check
      throws
      evalHome
      ;
  };

  home-shared-hooks-skills = import ./hooks-skills.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalHome
      homeDirectory
      ;
  };

  home-omp = import ./omp.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalHomeWith
      sharedModule
      ompModule
      ;
  };

  home-oxide-code = import ./oxide-code.nix {
    inherit
      pkgs
      lib
      check
      throws
      evalHomeWith
      sharedModule
      ompModule
      oxideCodeModule
      ;
  };
}
// claudeCodeChecks
