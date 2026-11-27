# ==================================================================================================
# MCP Server Wrappers and Presets
# ==================================================================================================

{
  pkgs,
  lib,
  agentsLib,
  mcpCfg,
}:

let
  esc = lib.escapeShellArg;

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
          ++ lib.optional mcpCfg.uv.isolatedConfig "--no-config"
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

  # ------------------------------------------------------------------------------------------------
  # Preset definitions
  # ------------------------------------------------------------------------------------------------
  inherit (mcpCfg) presets;

  curlBin = lib.getExe pkgs.curl;

  githubPreset =
    let
      p = presets.github;
      ghBin = lib.getExe p.ghPackage;
      fallbackCheck = lib.optionalString (p.fallbackTokenFile != null) ''
        if [[ -s ${esc p.fallbackTokenFile} ]]; then
          status=$(
            printf 'Authorization: Bearer %s\n' "$token" \
              | ${esc curlBin} https://api.github.com/rate_limit \
                -fsSL \
                --connect-timeout 3 \
                --max-time 5 \
                -o /dev/null \
                -w '%{http_code}' \
                --header @- \
                2>/dev/null \
              || true
          )
          if [[ "$status" == 401 ]]; then
            token="$(<${esc p.fallbackTokenFile})"
          fi
        fi
      '';
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.github;
      type = lib.mkDefault "stdio";
      command = lib.mkDefault [
        (lib.getExe p.package)
        "stdio"
      ];
      setup = lib.mkDefault ''
        if [[ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] \
          && token=$(${esc ghBin} auth token 2>/dev/null) \
          && [[ -n "$token" ]]; then
          ${fallbackCheck}
          export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
        fi
      '';
    };

  gitlabPreset =
    let
      p = presets.gitlab;
      glabBin = lib.getExe p.glabPackage;
      fallbackBranch = lib.optionalString (p.fallbackTokenFile != null) ''
        elif [[ -f ${esc p.fallbackTokenFile} ]]; then
          export GITLAB_PERSONAL_ACCESS_TOKEN="$(cat ${esc p.fallbackTokenFile})"
          ${lib.optionalString (p.fallbackApiUrl != null) "export GITLAB_API_URL=${esc p.fallbackApiUrl}"}
      '';
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.gitlab;
      type = lib.mkDefault "stdio";
      command = lib.mkDefault [ (lib.getExe p.package) ];
      envVars.GITLAB_TOOLSETS = lib.mkDefault (lib.concatStringsSep "," p.toolsets);
      setup = lib.mkDefault ''
        if host=$(${esc glabBin} config get host 2>/dev/null) \
          && [[ -n "$host" ]] \
          && token=$(${esc glabBin} config get token --host "$host" 2>/dev/null) \
          && [[ -n "$token" ]]; then
          export GITLAB_PERSONAL_ACCESS_TOKEN="$token"
          export GITLAB_API_URL="https://''${host}/api/v4"
        ${fallbackBranch}
        fi
      '';
    };

  exaPreset =
    let
      p = presets.exa;
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.exa;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "npx";
      command = lib.mkDefault [ "exa-mcp-server" ];
      envFiles = lib.optionalAttrs (p.apiKeyFile != null) {
        EXA_API_KEY = lib.mkDefault p.apiKeyFile;
      };
      envVars.ENABLED_TOOLS = lib.mkDefault (lib.concatStringsSep "," p.enabledTools);
    };

  chromeDevtoolsPreset =
    let
      p = presets.chromeDevtools;
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.chromeDevtools;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "npx";
      command = lib.mkDefault (
        [ "chrome-devtools-mcp" ]
        ++ lib.optional (p.chromiumPackage != null) "--executable-path=${lib.getExe p.chromiumPackage}"
        ++ [ "--isolated" ]
        ++ lib.optional p.headless "--headless"
      );
    };

  deepwikiPreset = {
    displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.deepwiki;
    type = lib.mkDefault "http";
    url = lib.mkDefault presets.deepwiki.url;
  };

  scraplingPreset =
    let
      p = presets.scrapling;
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.scrapling;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "uvx";
      command = lib.mkDefault (
        [
          "--from"
          "scrapling[ai]@latest"
          "scrapling-mcp"
        ]
        ++ lib.optional (p.chromiumPackage != null) "--executable-path=${lib.getExe p.chromiumPackage}"
      );
    };

  atlassianPreset =
    let
      p = presets.atlassian;
    in
    {
      displayName = lib.mkDefault agentsLib.mcp.presetDisplayNames.atlassian;
      type = lib.mkDefault "stdio";
      runtime = lib.mkDefault "uvx";
      command = lib.mkDefault [ "mcp-atlassian@latest" ];
      clearProxy = lib.mkDefault p.clearProxy;
      envFiles = lib.optionalAttrs (p.tokenFile != null) {
        CONFLUENCE_PERSONAL_TOKEN = lib.mkDefault p.tokenFile;
      };
      envVars = lib.optionalAttrs (p.url != null) {
        CONFLUENCE_URL = lib.mkDefault p.url;
      };
    };

  presetServers =
    lib.optionalAttrs presets.atlassian.enable { atlassian = atlassianPreset; }
    // lib.optionalAttrs presets.chromeDevtools.enable { chromeDevtools = chromeDevtoolsPreset; }
    // lib.optionalAttrs presets.deepwiki.enable { deepwiki = deepwikiPreset; }
    // lib.optionalAttrs presets.exa.enable { exa = exaPreset; }
    // lib.optionalAttrs presets.github.enable { github = githubPreset; }
    // lib.optionalAttrs presets.gitlab.enable { gitlab = gitlabPreset; }
    // lib.optionalAttrs presets.scrapling.enable { scrapling = scraplingPreset; };

  enabledServers = lib.filterAttrs (_: server: server.enable) mcpCfg.servers;
  resolvedServers = lib.mapAttrs resolveServer enabledServers;
  displayNames = lib.mapAttrs (_: server: server.displayName) enabledServers;
in
{
  inherit
    displayNames
    presetServers
    resolvedServers
    ;
}
