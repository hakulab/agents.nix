# ==================================================================================================
# Shared Browser Tools
# ==================================================================================================

{
  pkgs,
  lib,
  driver ? pkgs.playwright-driver,
}:

let
  inherit (driver) browsers;

  chromium = pkgs.callPackage ./chromium.nix { inherit driver; };
in
pkgs.runCommand "browser-tools"
  {
    nativeBuildInputs = [
      pkgs.makeBinaryWrapper
    ];

    passthru = { inherit driver browsers chromium; };
    meta = {
      description = "Playwright CLI and its matching browsers";
      license = lib.licenses.asl20;
      platforms = lib.platforms.unix;
      mainProgram = "playwright";
    };
  }
  ''
    mkdir -p "$out/bin" "$out/lib/node_modules"
    ln -s ${driver} "$out/lib/node_modules/playwright"
    ln -s ${lib.getExe chromium} "$out/bin/chromium"
    makeWrapper ${lib.getExe pkgs.nodejs_26} "$out/bin/playwright" \
      --set PLAYWRIGHT_BROWSERS_PATH ${browsers} \
      --add-flags ${driver}/cli.js
  ''
