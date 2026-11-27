# ==================================================================================================
# OMP MCP Configuration
# ==================================================================================================

{
  lib,
  resolved,
  enabledServers,
}:

let
  activeServers = lib.filter (name: resolved.mcp.servers ? ${name}) enabledServers;

  mkEntry =
    name:
    lib.nameValuePair (resolved.mcp.displayNames.${name} or name) (
      resolved.mcp.servers.${name} // { timeout = resolved.mcp.timeouts.startup * 1000; }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry activeServers);
}
