# ==================================================================================================
# ACP Home Manager Checks
# ==================================================================================================

{
  lib,
  fixtures,
  hasPkgPrefix,
}:

let
  inherit (fixtures) desktopCfg headlessCfg;
in
[
  {
    name = "acp installs acpx and enabled adapters and writes ~/.acpx/config.json";
    ok =
      lib.isDerivation desktopCfg.agents.acp.package
      && hasPkgPrefix "acpx-" desktopCfg.home.packages
      && hasPkgPrefix "claude-agent-acp-" desktopCfg.home.packages
      && hasPkgPrefix "codex-acp-" desktopCfg.home.packages
      && desktopCfg.home.file ? ".acpx/config.json";
  }
  {
    name = "acp auto-targets wrapped claude and codex executables when those programs are enabled";
    ok =
      desktopCfg.agents.acp.claudeAdapter.executable != null
      && lib.hasSuffix "/bin/claude" desktopCfg.agents.acp.claudeAdapter.executable
      && desktopCfg.agents.acp.codexAdapter.executable != null
      && lib.hasSuffix "/bin/codex" desktopCfg.agents.acp.codexAdapter.executable;
  }
  {
    name = "acp omits disabled adapters and leaves executables null when programs are disabled";
    ok =
      headlessCfg.agents.acp.claudeAdapter.executable == null
      && headlessCfg.agents.acp.codexAdapter.executable == null
      && !(hasPkgPrefix "claude-agent-acp-" headlessCfg.home.packages)
      && hasPkgPrefix "codex-acp-" headlessCfg.home.packages
      && hasPkgPrefix "acpx-" headlessCfg.home.packages;
  }
]
