# ==================================================================================================
# Shared MCP Server Module (agents.mcp)
# ==================================================================================================

{
  self,
  agentsLib,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents.mcp;
  esc = lib.escapeShellArg;

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  mcpGateSubmodule = lib.types.submodule {
    options = {
      tool = lib.mkOption {
        type = lib.types.str;
        description = "MCP tool name requiring confirmation";
      };

      reason = lib.mkOption {
        type = lib.types.str;
        description = "Why this MCP tool requires confirmation";
      };
    };
  };

  mcpServerSubmodule = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this MCP server is enabled";
        };

        type = lib.mkOption {
          type = lib.types.enum [
            "stdio"
            "http"
          ];
          default = "stdio";
          description = "MCP transport type";
        };

        displayName = lib.mkOption {
          type = lib.types.str;
          default = agentsLib.mcp.presetDisplayNames.${name} or name;
          description = "Display name used in permission rules";
        };

        command = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Command and arguments for stdio MCP servers";
        };

        url = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Endpoint URL for HTTP MCP servers";
        };

        envVars = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Static environment variables exported by the server wrapper";
        };

        envFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Runtime file paths read into environment variables on launch";
        };

        setup = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Shell snippet run before executing the stdio command";
        };

        clearProxy = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Clear HTTP(S) proxy environment variables before launching the server";
        };

        runtime = lib.mkOption {
          type = lib.types.enum [
            "direct"
            "npx"
            "uvx"
          ];
          default = "direct";
          description = "Launcher runtime for stdio MCP servers";
        };

        permissions = {
          allowTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "MCP tool names allowed without prompting for this server";
          };

          gateTools = lib.mkOption {
            type = lib.types.listOf mcpGateSubmodule;
            default = [ ];
            description = "MCP tool gate entries registered for this server";
          };
        };
      };
    }
  );

  # ------------------------------------------------------------------------------------------------
  # Wrapper builders
  # ------------------------------------------------------------------------------------------------
  nodejs = pkgs.nodejs_26;
  nodeSetup = ''
    export PATH="${nodejs}/bin:$PATH"
    ${agentsLib.proxy.nodeProxyScript}
  '';

  exportFromFile = var: file: ''
    if [ -f ${esc file} ]; then
      export ${var}="$(cat ${esc file})"
    fi
  '';

  exportLiteral = var: value: ''
    export ${var}=${esc value}
  '';

  mkStdioWrapper =
    name: server:
    let
      command =
        if server.runtime == "npx" then
          [
            "npx"
            "-y"
          ]
          ++ server.command
        else if server.runtime == "uvx" then
          [
            (lib.getExe' pkgs.uv "uvx")
          ]
          ++ lib.optional cfg.uv.isolatedConfig "--no-config"
          ++ server.command
        else
          server.command;

      runtimeSetup = lib.optionalString (server.runtime == "npx") nodeSetup;
      proxySetup = lib.optionalString server.clearProxy agentsLib.proxy.clearProxyEnv;

      exports = lib.concatStrings (
        lib.mapAttrsToList exportFromFile server.envFiles ++ lib.mapAttrsToList exportLiteral server.envVars
      );

      setup = lib.concatStringsSep "\n" (
        lib.filter (part: part != "") [
          exports
          runtimeSetup
          proxySetup
          server.setup
        ]
      );
    in
    pkgs.writeShellScriptBin "${name}-mcp" ''
      set -euo pipefail
      ${setup}
      exec ${lib.escapeShellArgs command} "$@"
    '';

  # ------------------------------------------------------------------------------------------------
  # Server resolution
  # ------------------------------------------------------------------------------------------------
  resolveServer =
    name: server:
    if server.type == "http" then
      {
        type = "http";
        inherit (server) url;
      }
    else
      {
        type = "stdio";
        command = lib.getExe (mkStdioWrapper name server);
      };

  enabledServers = lib.filterAttrs (_: server: server.enable) cfg.servers;
  resolvedServers = lib.mapAttrs resolveServer enabledServers;
  displayNames = lib.mapAttrs (_: server: server.displayName) enabledServers;
in
{
  imports = [
    (import ./presets {
      inherit self agentsLib;
    })
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    mcp = {
      servers = lib.mkOption {
        type = lib.types.attrsOf mcpServerSubmodule;
        default = { };
        description = "Declared MCP servers wrapped and exposed to assistants";
      };

      disabledServers = agentsLib.mcp.mkDisabledServersOption {
        description = "Global MCP servers to disable across all assistants";
      };

      timeouts = {
        startup = lib.mkOption {
          type = lib.types.int;
          default = 120;
          description = "Startup timeout in seconds for MCP servers";
        };
      };

      uv = {
        isolatedConfig = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Pass --no-config to uvx when launching Python MCP servers";
        };
      };
    };

    _internal.mcp = lib.mkOption {
      type = lib.types.anything;
      internal = true;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = lib.mapAttrsToList (name: server: {
      assertion =
        server.enable -> (if server.type == "http" then server.url != null else server.command != [ ]);
      message =
        if server.type == "http" then
          "agents.mcp.servers.${name}.url must be set for HTTP MCP servers"
        else
          "agents.mcp.servers.${name}.command must be non-empty for stdio MCP servers";
    }) cfg.servers;

    # ----------------------------------------------------------------------------------------------
    # Internal exports
    # ----------------------------------------------------------------------------------------------
    agents._internal.mcp = {
      inherit displayNames;
      inherit (cfg) disabledServers timeouts;
      inherit (agentsLib.mcp) computeEnabledServers mkMcpOptions;
      serverNames = builtins.attrNames resolvedServers;
      servers = resolvedServers;
    };
  };
}
