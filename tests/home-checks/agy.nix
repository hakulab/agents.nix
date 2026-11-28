# ==================================================================================================
# Antigravity CLI Home Manager Checks
# ==================================================================================================

{
  lib,
  harness,
  homeModules,
}:

let
  inherit (harness) check evalHomeWith homeDirectory;

  cfg = evalHomeWith [ homeModules.agy ] {
    agents = {
      agy = {
        enable = true;
        agents.enabledAgents = [
          "researcher"
          "reviewer"
        ];
      };

      instructions = {
        enable = false;
        extraSections = "Project guidance.";
      };

      roles.definitions.researcher.agy = {
        mainAgent = true;
        inheritCustomizations = false;
        tools = [ "view_file" ];
      };

      skills.sources.sample.source = "/fixtures/sample-skill";

      mcp = {
        disabledServers = [ "hidden" ];
        servers = {
          local = {
            displayName = "Local";
            command = [ "example-mcp" ];
            envFiles.MCP_TOKEN = "/run/secrets/mcp-token";
          };

          remote = {
            displayName = "Remote";
            type = "http";
            url = "https://example.test/mcp";
          };

          hidden = {
            displayName = "Hidden";
            command = [ "example-mcp" ];
          };
        };
      };
    };
  };

  agyConfigDir = "${homeDirectory}/.gemini/config";
  researcher = cfg.home.file."${agyConfigDir}/agents/researcher.md".text;
  reviewer = cfg.home.file."${agyConfigDir}/agents/reviewer.md".text;
in
check "home-agy" [
  {
    name = "agy writes shared customizations while leaving sign-in settings writable";
    ok =
      cfg.home.file.".gemini/AGENTS.md".text == "Project guidance."
      && cfg.home.file."${agyConfigDir}/skills/sample".source == "/fixtures/sample-skill"
      && !(cfg.home.file ? ".gemini/antigravity-cli/settings.json");
  }
  {
    name = "agy renders selected subagents with native model tiers and read-only tools";
    ok =
      lib.hasInfix "mainAgent: false\nmodel: inherit\nexcludeDefaultComponents: true\ninheritMcp: false" reviewer
      && lib.hasInfix ''tools: ["view_file","search_web","read_url_content"]'' reviewer
      && lib.hasInfix "mainAgent: true\nmodel: flash\nexcludeDefaultComponents: true\ninheritCustomizations: false\ninheritMcp: false" researcher
      && lib.hasInfix ''tools: ["view_file"]'' researcher
      && lib.hasInfix cfg.agents.resolved.agentRoles.reviewer.prompt reviewer
      && !(cfg.home.file ? "${agyConfigDir}/agents/implementer.md");
  }
  {
    name = "agy uses the runtime MCP wrapper and omits globally disabled servers";
    ok =
      cfg.programs.antigravity-cli.mcpServers == {
        Local.command = cfg.agents.resolved.mcp.servers.local.command;
        Remote.url = "https://example.test/mcp";
      };
  }
]
