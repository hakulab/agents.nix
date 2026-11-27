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
  check =
    name: assertions:
    let
      failed = lib.filter (item: !item.ok) assertions;
      message = lib.concatMapStringsSep "\n" (item: "  - ${item.name}") failed;
    in
    if failed != [ ] then
      throw "check `${name}` failed:\n${message}"
    else
      pkgs.runCommand "check-${name}" { } ''
        touch "$out"
      '';

  throws = expr: !(builtins.tryEval (builtins.deepSeq expr true)).success;

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
