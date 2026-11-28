# ==================================================================================================
# Antigravity CLI MCP Configuration
# ==================================================================================================

{
  lib,
  resolved,
  enabledServers,
}:

{
  serversConfig = builtins.listToAttrs (
    map (
      name:
      lib.nameValuePair resolved.mcp.displayNames.${name} (
        removeAttrs resolved.mcp.servers.${name} [ "type" ]
      )
    ) enabledServers
  );
}
