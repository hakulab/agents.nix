# ==================================================================================================
# GitLab MCP Server Preset
# ==================================================================================================

{
  agentsLib,
  packagesFor,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  p = config.agents.mcp.presets.gitlab;
  selfPackages = packagesFor pkgs.stdenv.hostPlatform.system;
  esc = lib.escapeShellArg;

  glabBin = lib.getExe p.glabPackage;

  fallbackBranch = lib.optionalString (p.fallbackTokenFile != null) ''
    elif [[ -f ${esc p.fallbackTokenFile} ]]; then
      export GITLAB_PERSONAL_ACCESS_TOKEN="$(cat ${esc p.fallbackTokenFile})"
      ${lib.optionalString (p.fallbackApiUrl != null) "export GITLAB_API_URL=${esc p.fallbackApiUrl}"}
  '';
in
{
  options.agents.mcp.presets.gitlab = {
    enable = lib.mkEnableOption "GitLab MCP server preset";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mcp-server-gitlab or selfPackages.mcp-server-gitlab;
      description = "GitLab MCP server package";
    };

    glabPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.glab;
      description = "GitLab CLI package used to read the active host and token";
    };

    fallbackTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime file path to a fallback GitLab token when glab is not configured";
    };

    fallbackApiUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Fallback GitLab API v4 URL paired with fallbackTokenFile";
    };

    toolsets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "branches"
        "issues"
        "labels"
        "merge_requests"
        "pipelines"
        "projects"
        "repositories"
      ];
      description = "GitLab MCP toolsets enabled by default";
    };
  };

  config.agents.mcp.servers = lib.mkIf p.enable {
    gitlab = {
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
  };
}
