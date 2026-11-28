# ==================================================================================================
# Codex Permissions
# ==================================================================================================

{
  lib,
  resolved,
  enabledServers,
}:

let
  policy = resolved.permissions;
  forEnabledServers = lib.filter (entry: lib.elem entry.server enabledServers);
  mcpAllows = forEnabledServers policy.mcpAllows;
  mcpGates = forEnabledServers policy.mcpGates;

  toPattern = command: lib.concatStringsSep ", " (map builtins.toJSON (lib.splitString " " command));

  toAllowRule = pattern: ''
    prefix_rule(
        pattern = [${pattern}],
        decision = "allow",
    )
  '';

  gateRules = map (gate: ''
    prefix_rule(
        pattern = [${toPattern gate.command}],
        decision = "prompt",
        justification = ${builtins.toJSON gate.reason},
    )
  '') policy.gates.commands;

  # Codex applies the strictest matching decision, and `allow` runs a command outside the sandbox
  # without review, so only read-only commands and trusted skill scripts render as allows.
  allowRules = map (command: toAllowRule (toPattern command)) policy.allows.commands.readOnly;

  skillRules = map (path: toAllowRule (builtins.toJSON path)) (
    resolved.mkSkillScriptPaths "${resolved.configDirs.codex}/skills"
  );

  toMcpApprovals =
    mode: entries:
    lib.foldl' lib.recursiveUpdate { } (
      map (entry: { ${entry.server}.tools.${entry.tool}.approval_mode = mode; }) entries
    );

  mcpGateItems = map (gate: {
    name = "`${gate.tool}` on the ${gate.displayName} MCP server";
    inherit (gate) reason;
  }) mcpGates;

  indentMultiline = text: lib.replaceStrings [ "\n" ] [ "\n  " ] (lib.trim text);

  toPolicyItems = lib.concatMapStringsSep "\n" (
    entry:
    if builtins.isString entry then
      "- ${indentMultiline entry}"
    else
      let
        name = entry.name or "`${entry.command}`";
      in
      "- ${name}: ${indentMultiline entry.reason}"
  );
in
{
  rules = lib.concatStringsSep "\n" (gateRules ++ allowRules ++ skillRules);

  mcpApprovals = lib.recursiveUpdate (toMcpApprovals "approve" mcpAllows) (
    toMcpApprovals "prompt" mcpGates
  );

  extraPolicy = ''
    ## Allowed without user approval

    ${toPolicyItems policy.allows.policies}

    ## Requires the user's explicit approval, including approval given earlier in the conversation

    ${toPolicyItems (policy.gates.commands ++ mcpGateItems ++ policy.gates.policies)}
  '';
}
