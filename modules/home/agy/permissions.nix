# ==================================================================================================
# Antigravity CLI Permissions
# ==================================================================================================

{
  config,
  lib,
  agentsLib,
  enabledServers,
}:

let
  inherit (config.agents)
    dataDir
    instructions
    providers
    resolved
    ;

  policy = resolved.permissions;
  instructionsDir = "${dataDir}/instructions";

  toCommand = command: "command(${command})";
  toMcp = entry: "mcp(${resolved.mcp.displayNames.${entry.server}}/${entry.tool})";
  forEnabledServers = lib.filter (entry: lib.elem entry.server enabledServers);

  # ------------------------------------------------------------------------------------------------
  # Deny rules
  # ------------------------------------------------------------------------------------------------
  profileKeyFile =
    profile:
    if profile.provider == null then
      null
    else
      agentsLib.profiles.apiKeyFileFor providers.${profile.provider} "agy";

  keyFiles = lib.unique (
    lib.filter (file: file != null) (
      map profileKeyFile (builtins.attrValues resolved.clientProfiles.agy)
    )
  );
in
{
  agentMode = "auto";
  enableTerminalSandbox = true;
  toolPermission = "proceed-in-sandbox";

  permissions = {
    allow =
      map toCommand policy.allows.commands.sandboxSafe
      ++ map toMcp (forEnabledServers policy.mcpAllows)
      ++ lib.optional instructions.enable "read_file(${instructionsDir})";

    ask = map toCommand policy.gateCommands ++ map toMcp (forEnabledServers policy.mcpGates);

    deny =
      map (path: "read_file(${path})") keyFiles
      ++ lib.optional instructions.enable "write_file(${instructionsDir})";
  };
}
