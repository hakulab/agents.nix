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
  profileWrapArgs ? null,
}:

let
  inherit (import ./models.nix { inherit lib resolved; }) defaultSlug;
in
agentsLib.wrapPackage {
  inherit pkgs;
  pkg = package;
  bin = "agy";
  wrapArgs =
    (
      if profileWrapArgs != null then
        profileWrapArgs
      else
        [
          "--add-flags"
          (lib.escapeShellArgs [
            "--model"
            defaultSlug
          ])
        ]
    )
    ++ agentsLib.proxy.mkProxyWrapArgs proxy;
}
