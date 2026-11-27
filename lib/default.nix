# ==================================================================================================
# agents.nix Pure Nix Library
# ==================================================================================================

{
  lib,
}:

let
  mcp = import ./mcp.nix { inherit lib; };
  models = import ./models.nix { inherit lib; };
  permissions = import ./permissions { inherit lib mcp; };
  profiles = import ./profiles.nix { inherit lib models; };
  prompts = import ./prompts.nix { inherit lib; };
  proxy = import ./proxy.nix { inherit lib; };
  wrapPackage = import ./wrap-package.nix { inherit lib; };
in
{
  inherit
    mcp
    models
    permissions
    profiles
    prompts
    proxy
    wrapPackage
    ;
}
