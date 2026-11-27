# ==================================================================================================
# Pure Library Checks
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
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
      check
      throws
      evalOptionSet
      ;
  };

  lib-permissions = import ./permissions.nix {
    inherit
      lib
      agentsLib
      check
      throws
      ;
  };

  lib-profiles = import ./profiles.nix {
    inherit
      agentsLib
      check
      throws
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
