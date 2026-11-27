# ==================================================================================================
# OMP MCP Configuration
# ==================================================================================================

{
  lib,
  shared,
  enabledServers,
}:

let
  activeServers = lib.filter (name: shared.mcp.servers ? ${name}) enabledServers;

  mkEntry =
    name:
    lib.nameValuePair (shared.mcp.displayNames.${name} or name) (
      shared.mcp.servers.${name} // { timeout = shared.mcp.timeouts.startup * 1000; }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry activeServers);
}
