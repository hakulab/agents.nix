# ==================================================================================================
# Antigravity CLI Home Manager Checks
# ==================================================================================================

{
  lib,
  harness,
  fixtures,
}:

let
  inherit (harness) check throws homeDirectory;

  inherit (fixtures)
    agyPackages
    managedCfg
    extraHeadersCfg
    optedOutCfg
    fallbackCfg
    explicitExecutableCfg
    nativeAgyAcpCfg
    ;

  agyConfigDir = "${homeDirectory}/.gemini/config";
  researcher = managedCfg.home.file."${agyConfigDir}/agents/researcher.md".text;
  reviewer = managedCfg.home.file."${agyConfigDir}/agents/reviewer.md".text;
  defaultResearcher = optedOutCfg.home.file."${agyConfigDir}/agents/researcher.md".text;

  expectedReviewerFrontmatter = lib.trim ''
    mainAgent: false
    model: pro
    excludeDefaultComponents: true
    inheritMcp: false
  '';

  expectedResearcherFrontmatter = lib.trim ''
    mainAgent: true
    model: inherit
    excludeDefaultComponents: true
    inheritCustomizations: false
    inheritMcp: false
  '';
in
check "home-agy" [
  # ------------------------------------------------------------------------------------------------
  # Shared customizations
  # ------------------------------------------------------------------------------------------------
  {
    name = "agy writes shared customizations while leaving sign-in settings writable";
    ok =
      managedCfg.home.file.".gemini/AGENTS.md".text == managedCfg.agents.resolved.instructions
      && lib.hasInfix "Project guidance." managedCfg.home.file.".gemini/AGENTS.md".text
      && managedCfg.home.file."${agyConfigDir}/skills/sample".source == "/fixtures/sample-skill"
      && !(managedCfg.home.file ? ".gemini/antigravity-cli/settings.json");
  }
  {
    name = "agy renders selected subagents with native model tiers and read-only tools";
    ok =
      lib.hasInfix expectedReviewerFrontmatter reviewer
      && lib.hasInfix ''tools: ["view_file","search_web","read_url_content"]'' reviewer
      && lib.hasInfix expectedResearcherFrontmatter researcher
      && lib.hasInfix ''tools: ["view_file"]'' researcher
      && lib.hasInfix managedCfg.agents.resolved.agentRoles.reviewer.prompt reviewer
      && !(managedCfg.home.file ? "${agyConfigDir}/agents/implementer.md")
      && lib.hasInfix "model: flash\n" defaultResearcher;
  }
  {
    name = "agy uses the runtime MCP wrapper and omits globally disabled servers";
    ok =
      managedCfg.programs.antigravity-cli.mcpServers == {
        Local.command = managedCfg.agents.resolved.mcp.servers.local.command;
        Remote.url = "https://example.test/mcp";
      };
  }

  # ------------------------------------------------------------------------------------------------
  # Auth profiles
  # ------------------------------------------------------------------------------------------------
  {
    name = "agy selects official and native Gemini API-key profiles";
    ok =
      builtins.attrNames managedCfg.agents.resolved.clientProfiles.agy == [
        "ai-studio"
        "official"
      ]
      && managedCfg.home.activation ? agyAuthProfile
      && lib.any (pkg: lib.getName pkg == "agy-switch") managedCfg.home.packages;
  }
  {
    name = "agy rejects provider extraHeaders with an eval-time assertion";
    ok = throws extraHeadersCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # ACP executable selection and installation
  # ------------------------------------------------------------------------------------------------
  {
    name = "agy uses the managed CLI for ACP by default";
    ok = managedCfg.agents.acp.agyAdapter.executable == "${managedCfg.home.profileDirectory}/bin/agy";
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
    name = "agy keeps the managed CLI installed when ACP registration is disabled";
    ok = lib.elem optedOutCfg.programs.antigravity-cli.package optedOutCfg.home.packages;
  }
  {
    name = "agy skips the fallback package when programs.antigravity-cli already provides agy";
    ok =
      nativeAgyAcpCfg.agents.acp.agyAdapter.executable == null
      && builtins.length (agyPackages nativeAgyAcpCfg) == 1;
  }
]
