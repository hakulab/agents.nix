# ==================================================================================================
# Shared Permissions Module (agents.permissions)
# ==================================================================================================

{
  agentsLib,
}:

{
  config,
  lib,
  ...
}:

let
  cfg = config.agents;

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  commandGateSubmodule = lib.types.submodule {
    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command pattern requiring confirmation";
      };

      reason = lib.mkOption {
        type = lib.types.str;
        description = "Why this command requires confirmation";
      };
    };
  };

  policyGateSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Short title for this gated policy";
      };

      reason = lib.mkOption {
        type = lib.types.lines;
        description = "Explanation of the gated policy";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Policy assembly
  # ------------------------------------------------------------------------------------------------
  allServerDisplayNames = lib.mapAttrs (_: server: server.displayName) cfg.mcp.servers;
  enabledMcpServers = lib.filterAttrs (_: server: server.enable) cfg.mcp.servers;

  serverMcpAllows = lib.filterAttrs (_: tools: tools != [ ]) (
    lib.mapAttrs (_: server: server.permissions.allowTools) enabledMcpServers
  );

  serverMcpGates = lib.filterAttrs (_: gates: gates != [ ]) (
    lib.mapAttrs (_: server: server.permissions.gateTools) enabledMcpServers
  );

  resolvedPermissions = agentsLib.permissions.mkPolicy {
    inherit (cfg.permissions) ownRepositories;
    extraServerDisplayNames = allServerDisplayNames;
    extraAllowCommands = cfg.permissions.allowCommands;
    extraGateCommands = cfg.permissions.gateCommands;
    extraMcpAllows = serverMcpAllows;
    extraMcpGates = serverMcpGates;
    extraAllowPolicies = cfg.permissions.allowPolicies;
    extraGatePolicies = cfg.permissions.gatePolicies;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    permissions = {
      ownRepositories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Repository URL prefixes allowed for git push and pull operations";
      };

      allowCommands = {
        readOnly = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra read-only command patterns added to the allowlist";
        };

        mutating = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra mutating command patterns added to the allowlist";
        };
      };

      gateCommands = lib.mkOption {
        type = lib.types.listOf commandGateSubmodule;
        default = [ ];
        description = "Extra command gate entries merged into the permissions policy";
      };

      allowPolicies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra policy statements appended to the allowlist";
      };

      gatePolicies = lib.mkOption {
        type = lib.types.listOf policyGateSubmodule;
        default = [ ];
        description = "Extra policy entries appended to the gate list";
      };
    };

    resolved.permissions = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Resolved permission policy consumed by assistant adapters";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.resolved.permissions = resolvedPermissions;
}
