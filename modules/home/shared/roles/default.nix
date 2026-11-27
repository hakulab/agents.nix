# ==================================================================================================
# Shared Agent Roles Module (agents.roles)
# ==================================================================================================

{
  assetsDir,
}:

{
  config,
  lib,
  ...
}:

let
  cfg = config.agents;
  internal = cfg._internal;

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  roleSubmodule = lib.types.submodule {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        description = "Short description of when to delegate to this role";
      };

      prompt = lib.mkOption {
        type = lib.types.lines;
        description = "System prompt text for this agent role";
      };

      workload = lib.mkOption {
        type = lib.types.enum [
          "default"
          "flagship"
          "standard"
          "mini"
          "prose"
        ];
        default = "standard";
        description = "Workload tier selected for this role";
      };

      claude = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Claude Code-specific role fields";
      };

      codex = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Codex-specific role fields";
      };

      omp = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Oh My Pi-specific role fields";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Role normalization and options helper
  # ------------------------------------------------------------------------------------------------
  defaultDefinitions = import ./definitions.nix {
    inherit assetsDir;
    inherit (internal) promptFragments;
  };

  toLine = text: lib.replaceStrings [ "\n" ] [ " " ] (lib.trim text);

  normalizeRoles = lib.mapAttrs (
    _: role:
    role
    // {
      description = toLine role.description;
      prompt = lib.trim role.prompt;
    }
  );

  mkRoleOptions =
    {
      agentRoles,
      defaultEnabled ? builtins.attrNames agentRoles,
    }:
    let
      sharedAgentNames = builtins.attrNames agentRoles;
    in
    {
      inherit sharedAgentNames;

      mkEnabledAgentsOption =
        {
          description,
          names ? sharedAgentNames,
          default ? lib.filter (name: lib.elem name names) defaultEnabled,
        }:
        lib.mkOption {
          type = lib.types.listOf (lib.types.enum names);
          inherit default description;
        };
    };

  agentRoles = normalizeRoles cfg.roles.definitions;

  agentRoleOptions = mkRoleOptions {
    inherit agentRoles;
    inherit (cfg.roles) defaultEnabled;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    roles = {
      definitions = lib.mkOption {
        type = lib.types.attrsOf roleSubmodule;
        default = { };
        description = "Shared agent role definitions available to assistant adapters";
      };

      defaultEnabled = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = builtins.attrNames cfg.roles.definitions;
        description = "Default list of enabled agent role names";
      };
    };

    _internal = {
      agentRoles = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      agentRoleOptions = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents = {
    roles.definitions = lib.mapAttrs (
      _: role:
      lib.mapAttrs (
        _: value:
        if builtins.isAttrs value then lib.mapAttrs (_: lib.mkDefault) value else lib.mkDefault value
      ) role
    ) defaultDefinitions;

    _internal = {
      inherit
        agentRoleOptions
        agentRoles
        ;
    };
  };
}
