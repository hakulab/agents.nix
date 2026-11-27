# ==================================================================================================
# Package Wrapper Runtime Check
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
}:

let
  sampleEnvFile = pkgs.writeText "wrap-package-env-file" "from-file";

  samplePkg =
    (pkgs.writeShellScriptBin "hello-bin" ''
      printf '%s|%s|%s\n' "''${WRAP_ARG:-}" "''${STATIC_VAR:-}" "''${FILE_VAR:-}"
    '').overrideAttrs
      {
        pname = "hello-pkg";
        meta.mainProgram = "hello-bin";
      };

  wrappedPkg = agentsLib.wrapPackage {
    inherit pkgs;
    pkg = samplePkg;
    wrapArgs = [
      "--set"
      "WRAP_ARG"
      "from-wrap"
    ];
    envVars.STATIC_VAR = "from-static";
    envFiles.FILE_VAR = toString sampleEnvFile;
  };
in
assert wrappedPkg.meta.mainProgram == "hello-bin";
pkgs.runCommand "check-lib-wrap-package" { } ''
  output=$(${lib.getExe wrappedPkg})
  if [ "$output" != "from-wrap|from-static|from-file" ]; then
    echo "unexpected wrapped output: $output" >&2
    exit 1
  fi
  touch "$out"
''
