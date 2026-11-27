# ==================================================================================================
# Codex MCP Configuration
# ==================================================================================================

{
  lib,
  resolved,
  mcpApprovals,
  enabledServers,
}:

let
  availableServers = lib.filter (name: resolved.mcp.servers ? ${name}) enabledServers;

  mkEntry =
    name:
    let
      server = resolved.mcp.servers.${name};
      displayName = resolved.mcp.displayNames.${name} or name;
    in
    lib.nameValuePair displayName (
      {
        startup_timeout_sec = resolved.mcp.timeouts.startup;
      }
      // builtins.intersectAttrs {
        command = null;
        url = null;
      } server
      // mcpApprovals.${name} or { }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry availableServers);
  missingServers = lib.filter (name: !(resolved.mcp.servers ? ${name})) enabledServers;
}
