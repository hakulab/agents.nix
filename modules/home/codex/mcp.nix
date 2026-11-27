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
  fieldRenames = {
    command = "command";
    url = "url";
  };

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
      // lib.mapAttrs' (field: toml: lib.nameValuePair toml server.${field}) (
        lib.intersectAttrs server fieldRenames
      )
      // mcpApprovals.${name} or { }
    );
in
{
  serversConfig = builtins.listToAttrs (map mkEntry availableServers);
  missingServers = lib.filter (name: !(resolved.mcp.servers ? ${name})) enabledServers;
}
