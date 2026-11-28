# ==================================================================================================
# Permissions Policy Checks
# ==================================================================================================

{
  lib,
  agentsLib,
  harness,
}:

let
  inherit (harness) check throws;

  defaultPolicy = agentsLib.permissions.defaultPolicy;

  customPolicy = agentsLib.permissions.mkPolicy {
    ownRepositories = [ "github.com/example" ];
    extraServerDisplayNames.custom = "Custom";
    extraAllowCommands.readOnly = [ "example-status" ];
    extraGateCommands = [
      {
        command = "example-deploy";
        reason = "Deploys production services.";
      }
    ];
    extraMcpAllows.custom = [ "read_item" ];
    extraMcpGates.custom = [
      {
        tool = "delete_item";
        reason = "Deletes remote items.";
      }
    ];
  };
in
check "lib-permissions" [
  {
    name = "default policy evaluates cleanly";
    ok =
      defaultPolicy.ownRepositories == [ ]
      && builtins.length defaultPolicy.allowCommands > 0
      && builtins.length defaultPolicy.allows.commands.sandboxSafe > 0
      && builtins.length defaultPolicy.gateCommands > 0
      && builtins.length defaultPolicy.mcpAllows > 0
      && builtins.length defaultPolicy.mcpGates > 0;
  }
  {
    name = "custom policy extends commands and MCP servers";
    ok =
      customPolicy.ownRepositories == [ "github.com/example" ]
      && lib.elem "example-status" customPolicy.allowCommands
      && lib.elem "example-deploy" customPolicy.gateCommands
      && lib.any (
        entry: entry.server == "custom" && entry.displayName == "Custom" && entry.tool == "read_item"
      ) customPolicy.mcpAllows
      && lib.any (entry: entry.server == "custom" && entry.tool == "delete_item") customPolicy.mcpGates;
  }
  {
    name = "rejects allow overlapping gate";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.readOnly = [ "sudo ls" ];
      }
    );
  }
  {
    name = "rejects readOnly covering mutating";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.mutating = [ "ls -la" ];
      }
    );
  }
  {
    name = "rejects sandboxSafe not in readOnly";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.sandboxSafe = [ "git status --short" ];
      }
    );
  }
  {
    name = "rejects duplicate command";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.readOnly = [ "ls" ];
      }
    );
  }
  {
    name = "rejects duplicate sandboxSafe command";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.sandboxSafe = [ "gh pr view" ];
      }
    );
  }
  {
    name = "rejects wildcard command";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraAllowCommands.readOnly = [ "git *" ];
      }
    );
  }
  {
    name = "rejects unknown MCP server";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraMcpAllows.unknownServer = [ "list_things" ];
      }
    );
  }
  {
    name = "rejects MCP tool both allowed and gated";
    ok = throws (
      agentsLib.permissions.mkPolicy {
        extraMcpAllows.github = [ "merge_pull_request" ];
      }
    );
  }
]
