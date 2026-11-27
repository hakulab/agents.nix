# ==================================================================================================
# Claude Code MCP Configuration
# ==================================================================================================

{
  pkgs,
  resolved,
  enabledServers,
}:

let
  json = pkgs.formats.json { };

  serversConfig = builtins.listToAttrs (
    map (name: {
      name = resolved.mcp.displayNames.${name};
      value = resolved.mcp.servers.${name};
    }) enabledServers
  );

  configFile = json.generate "claude-code-mcp-config.json" {
    mcpServers = serversConfig;
  };
in
{
  inherit configFile;
}
