# ==================================================================================================
# OMP Permissions
# ==================================================================================================

{
  lib,
  resolved,
  mcp,
}:

let
  policy = resolved.permissions;
  mcpGates = lib.filter (gate: lib.elem gate.server mcp.enabledServers) policy.mcpGates;

  toPromptRules = lib.concatMap (
    command:
    map
      (match: {
        inherit match;
        approval = "prompt";
      })
      [
        command
        "${command} *"
      ]
  );
in
{
  tools = {
    # In yolo mode, critical-command overrides can bypass Bash prompt rules.
    approvalMode = "write";
    approval = {
      bash = "allow";
      # Eval can execute shells without passing through Bash's command rules.
      eval = "prompt";
    }
    // lib.listToAttrs (map (gate: lib.nameValuePair (mcp.toToolName gate) "prompt") mcpGates);
  };

  bash.patterns = toPromptRules policy.gateCommands;
}
