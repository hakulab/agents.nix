# ==================================================================================================
# Shared Nix Check Harness
# ==================================================================================================

{
  pkgs,
  lib,
}:

{
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
}
