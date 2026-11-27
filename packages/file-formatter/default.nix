# ==================================================================================================
# File Formatter
# ==================================================================================================

{
  pkgs,
  lib,
  dk,
}:

dk.writeNuApplication {
  name = "file-formatter";
  text = builtins.readFile ./file-formatter.nu;

  runtimeInputs = [
    pkgs.direnv
    pkgs.git
    pkgs.prek
  ];

  meta = {
    description = "Run repository pre-commit hooks on edited files";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "file-formatter";
  };
}
