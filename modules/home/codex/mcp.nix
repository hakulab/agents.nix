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
  mkEntry =
    name:
    let
      server = resolved.mcp.servers.${name};
      displayName = resolved.mcp.displayNames.${name};
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
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);
}
