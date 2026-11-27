# ==================================================================================================
# GitHub MCP Server Preset
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
  p = config.agents.mcp.presets.github;
  selfPackages = self.packages.${pkgs.stdenv.hostPlatform.system};
  esc = lib.escapeShellArg;

  curlBin = lib.getExe pkgs.curl;
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
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents.mcp.presets.github = {
    enable = lib.mkEnableOption "GitHub MCP server preset";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mcp-server-github or selfPackages.mcp-server-github;
      description = "GitHub MCP server package";
    };

    ghPackage = lib.mkOption {
      type = lib.types.package;
      default = config.programs.gh.package or pkgs.gh;
      description = "GitHub CLI package used to read the active auth token";
    };

    fallbackTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file path to a fallback GitHub token used on HTTP 401";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.mcp.servers = lib.mkIf p.enable {
    github = {
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
  };
}
