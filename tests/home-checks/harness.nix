# ==================================================================================================
# Home Manager Test Harness
# ==================================================================================================

{
  pkgs,
  lib,
  home-manager,
  homeModules,
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
in
baseHarness
// {
  inherit
    homeDirectory
    evalModulesWith
    evalModules
    evalHomeWith
    evalHome
    ;
}
