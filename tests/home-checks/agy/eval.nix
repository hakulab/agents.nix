# ==================================================================================================
# Antigravity CLI Home Manager Checks
# ==================================================================================================

{
  lib,
  harness,
  fixtures,
}:

let
  inherit (harness) check homeDirectory;

  inherit (fixtures)
    agyPackages
    stubAgy
    customizedCfg
    combinedCfg
    optedOutCfg
    fallbackCfg
    explicitExecutableCfg
    nullExecutableCfg
    ;

  agyConfigDir = "${homeDirectory}/.gemini/config";
  researcher = customizedCfg.home.file."${agyConfigDir}/agents/researcher.md".text;
  reviewer = customizedCfg.home.file."${agyConfigDir}/agents/reviewer.md".text;

  combinedRolesDir = "${combinedCfg.agents.resolved.configDirs.agy}/agents";
in
check "home-agy" [
  # ------------------------------------------------------------------------------------------------
  # Shared customizations
  # ------------------------------------------------------------------------------------------------
  {
    name = "agy writes shared customizations while leaving sign-in settings writable";
    ok =
      customizedCfg.home.file.".gemini/AGENTS.md".text == "Project guidance."
      && customizedCfg.home.file."${agyConfigDir}/skills/sample".source == "/fixtures/sample-skill"
      && !(customizedCfg.home.file ? ".gemini/antigravity-cli/settings.json");
  }
  {
    name = "agy renders selected subagents with native model tiers and read-only tools";
    ok =
      lib.hasInfix "mainAgent: false\nmodel: inherit\nexcludeDefaultComponents: true\ninheritMcp: false" reviewer
      && lib.hasInfix ''tools: ["view_file","search_web","read_url_content"]'' reviewer
      && lib.hasInfix "mainAgent: true\nmodel: flash\nexcludeDefaultComponents: true\ninheritCustomizations: false\ninheritMcp: false" researcher
      && lib.hasInfix ''tools: ["view_file"]'' researcher
      && lib.hasInfix customizedCfg.agents.resolved.agentRoles.reviewer.prompt reviewer
      && !(customizedCfg.home.file ? "${agyConfigDir}/agents/implementer.md");
  }
  {
    name = "agy uses the runtime MCP wrapper and omits globally disabled servers";
    ok =
      customizedCfg.programs.antigravity-cli.mcpServers == {
        Local.command = customizedCfg.agents.resolved.mcp.servers.local.command;
        Remote.url = "https://example.test/mcp";
      };
  }
  {
    name = "agy projects shared model overrides into subagent tiers";
    ok =
      lib.hasInfix "model: inherit\n" combinedCfg.home.file."${combinedRolesDir}/researcher.md".text
      && lib.hasInfix "model: pro\n" combinedCfg.home.file."${combinedRolesDir}/implementer.md".text;
  }

  # ------------------------------------------------------------------------------------------------
  # ACP executable selection and installation
  # ------------------------------------------------------------------------------------------------
  {
    name = "agy uses the managed CLI for ACP by default";
    ok = combinedCfg.agents.acp.agyAdapter.executable == "${combinedCfg.home.profileDirectory}/bin/agy";
  }
  {
    name = "agy installs one fallback ACP executable alongside the legacy Gemini CLI";
    ok =
      fallbackCfg.agents.acp.agyAdapter.executable == null
      && builtins.length (agyPackages fallbackCfg) == 1;
  }
  {
    name = "agy skips the fallback package when ACP uses an existing executable";
    ok = agyPackages explicitExecutableCfg == [ ];
  }
  {
    name = "agy reuses the installed native CLI when the ACP executable is null";
    ok = agyPackages nullExecutableCfg == [ stubAgy ];
  }
  {
    name = "agy keeps the managed CLI installed when ACP registration is disabled";
    ok = lib.elem optedOutCfg.programs.antigravity-cli.package optedOutCfg.home.packages;
  }
]
