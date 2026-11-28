# ==================================================================================================
# Permissions Policy Builder
# ==================================================================================================

{
  lib,
  mcp,
}:

let
  baseGates = import ./gates.nix;

  mergeMcpAttrs = lib.zipAttrsWith (_: lib.concatLists);

  validate =
    {
      knownServers,
      policy,
    }:
    import ./validate.nix {
      inherit lib knownServers policy;
    };

  mkPolicy =
    {
      ownRepositories ? [ ],
      extraServerDisplayNames ? { },
      extraAllowCommands ? { },
      extraGateCommands ? [ ],
      extraMcpAllows ? { },
      extraMcpGates ? { },
      extraAllowPolicies ? [ ],
      extraGatePolicies ? [ ],
    }:
    let
      serverDisplayNames = mcp.presetDisplayNames // extraServerDisplayNames;

      baseAllows = import ./allows.nix {
        inherit lib ownRepositories;
      };

      allows = baseAllows // {
        commands = {
          readOnly = baseAllows.commands.readOnly ++ (extraAllowCommands.readOnly or [ ]);
          mutating = baseAllows.commands.mutating ++ (extraAllowCommands.mutating or [ ]);
          sandboxSafe = baseAllows.commands.sandboxSafe ++ (extraAllowCommands.sandboxSafe or [ ]);
        };
        mcp = mergeMcpAttrs [
          baseAllows.mcp
          extraMcpAllows
        ];
        policies = baseAllows.policies ++ extraAllowPolicies;
      };

      gates = baseGates // {
        commands = baseGates.commands ++ extraGateCommands;
        mcp = mergeMcpAttrs [
          baseGates.mcp
          extraMcpGates
        ];
        policies = baseGates.policies ++ extraGatePolicies;
      };

      toMcpEntries =
        servers:
        lib.concatLists (
          lib.mapAttrsToList (
            server:
            map (
              entry:
              entry
              // {
                inherit server;
                displayName = serverDisplayNames.${server} or server;
              }
            )
          ) servers
        );

      policy = {
        inherit ownRepositories allows gates;
        allowCommands = allows.commands.readOnly ++ allows.commands.mutating;
        gateCommands = map (gate: gate.command) gates.commands;
        mcpAllows = toMcpEntries (
          lib.mapAttrs (
            _:
            map (tool: {
              inherit tool;
            })
          ) allows.mcp
        );
        mcpGates = toMcpEntries gates.mcp;
      };
    in
    validate {
      knownServers = builtins.attrNames serverDisplayNames;
      inherit policy;
    };
in
{
  inherit mkPolicy validate;
  defaultPolicy = mkPolicy { };
}
