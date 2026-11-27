# ==================================================================================================
# Home Manager Module Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  home-manager,
  sharedModule,
}:

let
  inherit (import ../lib.nix { inherit pkgs lib; }) check throws;

  homeDirectory = if pkgs.stdenv.isDarwin then "/Users/tester" else "/home/tester";

  evalHome =
    extraModule:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        sharedModule
        {
          home = {
            username = "tester";
            inherit homeDirectory;
            stateVersion = "26.05";
          };
        }
        extraModule
      ];
    }).config;
in
{
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
}
