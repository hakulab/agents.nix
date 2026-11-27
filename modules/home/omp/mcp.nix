# ==================================================================================================
# OMP MCP Configuration
# ==================================================================================================

{
  lib,
  resolved,
  enabledServers,
}:

let
  mkEntry =
    name:
    lib.nameValuePair resolved.mcp.displayNames.${name} (
      resolved.mcp.servers.${name} // { timeout = resolved.mcp.timeouts.startup * 1000; }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
