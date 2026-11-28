# ==================================================================================================
# Antigravity CLI Package
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
  resolved,
  proxy,
  package,
}:

let
  inherit (import ./models.nix { inherit lib resolved; }) defaultSlug;
in
agentsLib.wrapPackage {
  inherit pkgs;
  pkg = package;
  bin = "agy";
  wrapArgs = [
    "--add-flags"
    (lib.escapeShellArgs [
      "--model"
      defaultSlug
    ])
  ]
  ++ agentsLib.proxy.mkProxyWrapArgs proxy;
}
