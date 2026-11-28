# ==================================================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "3.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-AUTkTCpB35JxMori7xXYPMhhT5CzNwcwes5czFrFdBY=";
  };

  npmDepsHash = "sha256-THo+89bDALqFfYXAPILRn+aTLOmo5RDMAPl1EaMbWHo=";
  nodejs = pkgs.nodejs_26;

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-gitlab";
  };
}
