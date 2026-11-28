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
  # Allow rules
  # ------------------------------------------------------------------------------------------------

  # Command allows also apply outside the sandbox. Keep them scoped to forge inspections.
  commandAllows = lib.intersectLists policy.allows.commands.readOnly [
    "gh issue view"
    "gh pr checks"
    "gh pr diff"
    "gh pr list"
    "gh pr view"
    "gh run list"
    "glab ci status"
    "glab issue list"
    "glab issue view"
    "glab mr list"
    "glab mr view"
  ];

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
      map toCommand commandAllows
      ++ map toMcp (forEnabledServers policy.mcpAllows)
      ++ lib.optional instructions.enable "read_file(${instructionsDir})";

    ask = map toCommand policy.gateCommands ++ map toMcp (forEnabledServers policy.mcpGates);

    deny =
      map (path: "read_file(${path})") keyFiles
      ++ lib.optional instructions.enable "write_file(${instructionsDir})";
  };
}
