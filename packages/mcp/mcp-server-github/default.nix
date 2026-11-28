# ==================================================================================================
# MCP Server – GitHub
# ==================================================================================================

{
  pkgs,
  lib,
}:

let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  version = "2.3.0";
  baseUrl = "https://github.com/github/github-mcp-server/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-2+gyKyerUK+ON44M7rq7mFEqxIHkmL1dI52VqMKoqT4=";
    };

    aarch64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_arm64.tar.gz";
      hash = "sha256-b3nZdAarasWhn0GPJa1eyipzn41lHTtZWVy7kMC4tkg=";
    };

    x86_64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-xCCSbmpZvymxjrgMNvD0j6+3M8PACLsdSHwpT008b9c=";
    };
  };

  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Unsupported platform: ${platform}");
in
pkgs.stdenv.mkDerivation {
  pname = "mcp-server-github";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals isLinux [
    pkgs.autoPatchelfHook
  ];
  buildInputs = lib.optionals isLinux [
    pkgs.stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 github-mcp-server "$out/bin/mcp-server-github"
    runHook postInstall
  '';

  meta = {
    description = "MCP server for GitHub API operations";
    homepage = "https://github.com/github/github-mcp-server";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "mcp-server-github";
  };
}
