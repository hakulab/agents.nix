# ==================================================================================================
# OMP MCP Configuration
# ==================================================================================================

{
  lib,
  resolved,
  selectedServers,
}:

let
  sanitize =
    fallback: value:
    let
      # JavaScript lowercasing retains an ASCII letter from these two non-ASCII characters.
      lower = lib.toLower (builtins.replaceStrings [ "İ" "K" ] [ "i_" "k" ] value);
      parts = builtins.split "[^a-z0-9]+" lower;
      name = lib.concatStringsSep "_" (lib.filter (part: lib.isString part && part != "") parts);
    in
    if name == "" then fallback else name;

  serverNamespace = sanitize "server";

  byNamespace = lib.groupBy (name: serverNamespace resolved.mcp.displayNames.${name}) selectedServers;
  duplicates = lib.filterAttrs (_: servers: lib.length servers > 1) byNamespace;
  duplicateErrors = lib.mapAttrsToList (
    namespace: servers:
    "OMP MCP namespace ${builtins.toJSON namespace} is shared by enabled servers: ${lib.concatStringsSep ", " servers}"
  ) duplicates;

  enabledServers = lib.throwIf (
    duplicateErrors != [ ]
  ) (lib.concatStringsSep "\n" duplicateErrors) selectedServers;

  mkEntry =
    name:
    lib.nameValuePair resolved.mcp.displayNames.${name} (
      resolved.mcp.servers.${name} // { timeout = resolved.mcp.timeouts.startup * 1000; }
    );
in
{
  inherit enabledServers;
  serversConfig = builtins.listToAttrs (map mkEntry enabledServers);

  toToolName =
    entry:
    let
      server = serverNamespace entry.displayName;
      name = "mcp__${server}_${lib.removePrefix "${server}_" (sanitize "tool" entry.tool)}";
    in
    lib.throwIf (lib.stringLength name > 64) "OMP would hash the MCP tool name `${name}`" name;
}
