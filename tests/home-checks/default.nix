# ==================================================================================================
# Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  home-manager,
  homeModules,
  darwinPkgs,
  sharedModule,
  claudeCodeModule,
  codexModule,
  ompModule,
  oxideCodeModule,
}:

let
  inherit (import ../lib.nix { inherit pkgs lib; }) check throws;

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

  home-peripheral-tools = import ./tools.nix {
    inherit
      pkgs
      lib
      check
      homeModules
      darwinPkgs
      homeDirectory
      ;
    evalHomeWith = evalModulesWith;
  };
}
// claudeCodeChecks
