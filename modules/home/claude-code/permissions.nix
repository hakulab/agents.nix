# ==================================================================================================
# Claude Code Permissions
# ==================================================================================================

{
  lib,
  resolved,
  instructionsDir,
}:

let
  policy = resolved.permissions;
  inherit (policy) allows;

  # ------------------------------------------------------------------------------------------------
  # Allow rules
  # ------------------------------------------------------------------------------------------------
  toolNames = {
    webFetch = "WebFetch";
    webSearch = "WebSearch";
  };

  # Claude Code's `Bash(ls *)` matches `ls` with or without arguments, but never `lsof`.
  toAllowRule = command: "Bash(${command} *)";

  commandRules = map toAllowRule policy.allowCommands;
  skillRules = map toAllowRule (resolved.mkSkillScriptPaths "${resolved.configDirs.claude}/skills");
  mcpRules = map (entry: "mcp__${entry.displayName}__${entry.tool}") policy.mcpAllows;
  toolRules = map (tool: toolNames.${tool}) allows.tools;

  # A leading `//` makes a Claude Code path rule absolute.
  pathRules =
    lib.concatMap (path: [
      "Read(/${path}/**)"
      "Edit(/${path}/**)"
    ]) allows.paths
    ++ [
      "Read(/${instructionsDir}/**)"
    ];

  # The built-in IDE server is outside the shared MCP registry.
  builtinRules = [
    "mcp__ide"
  ];

  allowRules = commandRules ++ skillRules ++ mcpRules ++ toolRules ++ pathRules ++ builtinRules;

  # ------------------------------------------------------------------------------------------------
  # Deny rules
  # ------------------------------------------------------------------------------------------------
  denyRules = [
    # Explore runs on the main session's model, while the shared researcher covers the same
    # read-only search on the mini tier.
    "Agent(Explore)"
  ];

  # ------------------------------------------------------------------------------------------------
  # Auto mode
  # ------------------------------------------------------------------------------------------------
  softDenyClearance = ''
    Allow when the user explicitly approves the action, including approval already given in
    the conversation. Otherwise, block it even if an allow rule would permit it.
  '';

  toLine = text: lib.replaceStrings [ "\n" ] [ " " ] (lib.trim text);

  toProseRules = map (
    entry:
    if builtins.isString entry then
      toLine entry
    else
      let
        name = entry.name or "`${entry.command}`";
      in
      "${name}: ${toLine entry.reason}"
  );

  mcpGates = map (gate: {
    name = "`mcp__${gate.displayName}__${gate.tool}`";
    inherit (gate) reason;
  }) policy.mcpGates;

  toSoftDenyRules = entries: map (rule: "${rule} ${toLine softDenyClearance}") (toProseRules entries);

  autoMode = {
    classifyAllShell = false;

    environment = [
      "$defaults"
    ]
    ++ lib.optional (policy.ownRepositories != [ ]) (
      "Source control, in addition to the trusted repo and its remotes: "
      + lib.concatStringsSep ", " policy.ownRepositories
    );

    allow = [ "$defaults" ] ++ toProseRules policy.allows.policies;

    soft_deny = [
      "$defaults"
    ]
    ++ toSoftDenyRules (policy.gates.commands ++ mcpGates ++ policy.gates.policies);
  };
in
{
  permissions = {
    defaultMode = "auto";
    allow = allowRules;
    deny = denyRules;
  };

  skipDangerousModePermissionPrompt = true;

  inherit autoMode;
}
