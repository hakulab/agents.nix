# ==================================================================================================
# Shared Module Default Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalHome,
  homeDirectory,
}:

let
  defaultCfg = evalHome { };
  resolved = defaultCfg.agents.resolved;

  xdgCfg = evalHome {
    home.preferXdgDirectories = true;
    agents = {
      dataDir = "${homeDirectory}/.local/share/custom-agents";
      instructions.extraSections = "## Custom\n\nExtra guidance.";
      instructions.docs."team.md" = "# Team guide\n";
      roles.definitions.custom-role = {
        description = ''
          Custom
          role.
        '';
        prompt = "  Be concise.  ";
        workload = "mini";
      };
    };
  };

  readOnlyMutation = evalHome {
    agents.resolved = {
      dataDir = "/tmp/override";
    };
  };
in
check "home-shared-defaults" [
  # ------------------------------------------------------------------------------------------------
  # Data directory and config paths
  # ------------------------------------------------------------------------------------------------
  {
    name = "dataDir defaults to xdg.dataHome/agents-nix";
    ok = defaultCfg.agents.dataDir == "${defaultCfg.xdg.dataHome}/agents-nix";
  }
  {
    name = "resolved exposes default configDirs for claude, codex, and omp";
    ok =
      resolved.configDirs.claude == "${homeDirectory}/.claude"
      && resolved.configDirs.codex == "${homeDirectory}/.codex"
      && resolved.configDirs.omp == "${homeDirectory}/.omp/agent";
  }
  {
    name = "codex configDir follows home.preferXdgDirectories";
    ok = xdgCfg.agents.resolved.configDirs.codex == "${xdgCfg.xdg.configHome}/codex";
  }

  # ------------------------------------------------------------------------------------------------
  # Instructions and companion docs
  # ------------------------------------------------------------------------------------------------
  {
    name = "instructions render @docsDir@ without leftover placeholders";
    ok =
      lib.hasInfix "${defaultCfg.agents.dataDir}/instructions/code-design.md" resolved.instructions
      && !(lib.hasInfix "@docsDir@" resolved.instructions)
      && !(lib.hasInfix "@devkitSource@" resolved.instructions);
  }
  {
    name = "built-in companion docs are installed under xdg.dataFile";
    ok =
      defaultCfg.xdg.dataFile ? "agents-nix/instructions/code-design.md"
      && defaultCfg.xdg.dataFile ? "agents-nix/instructions/writing.md"
      && builtins.length (builtins.attrNames resolved.instructionDocs) == 8;
  }
  {
    name = "extraSections appends to instructions and custom docs extend defaults";
    ok =
      lib.hasSuffix "## Custom\n\nExtra guidance." xdgCfg.agents.resolved.instructions
      && xdgCfg.xdg.dataFile ? "custom-agents/instructions/code-design.md"
      && xdgCfg.xdg.dataFile ? "custom-agents/instructions/team.md";
  }

  # ------------------------------------------------------------------------------------------------
  # Agent roles
  # ------------------------------------------------------------------------------------------------
  {
    name = "all 9 built-in agent roles are loaded and normalized";
    ok =
      builtins.length (builtins.attrNames resolved.agentRoles) == 9
      && resolved.agentRoles ? architect
      && resolved.agentRoles ? implementer
      && resolved.agentRoles ? reviewer
      && !(lib.hasInfix "\n" resolved.agentRoles.architect.description);
  }
  {
    name = "custom roles extend built-in definitions and collapse multiline descriptions";
    ok =
      builtins.length (builtins.attrNames xdgCfg.agents.resolved.agentRoles) == 10
      && xdgCfg.agents.resolved.agentRoles.custom-role.description == "Custom role."
      && xdgCfg.agents.resolved.agentRoles.custom-role.prompt == "Be concise.";
  }

  # ------------------------------------------------------------------------------------------------
  # Defaults, permissions, formatter, and notify
  # ------------------------------------------------------------------------------------------------
  {
    name = "modelCatalog and permissions are populated by default";
    ok =
      resolved.modelCatalog.models ? "claude-opus-5-5"
      && resolved.permissions.allowCommands != [ ]
      && resolved.preferences.askTimeout == 300
      && resolved.preferences.plansDir == ".agents/plans";
  }
  {
    name = "fileFormatter and Nushell notify helpers resolve to executable store paths";
    ok =
      lib.hasSuffix "/bin/file-formatter" resolved.fileFormatter
      && lib.hasSuffix "/bin/agents-notify" resolved.notify.notifyScript
      && lib.hasSuffix "/bin/project-notify" resolved.notify.mkProjectNotifyScript;
  }
  {
    name = "notify toastyPackage defaults only on x86_64-linux";
    ok =
      (pkgs.stdenv.hostPlatform.system == "x86_64-linux")
      == (defaultCfg.agents.notify.toastyPackage != null);
  }
  {
    name = "default configuration has no failing assertions";
    ok = lib.all (a: a.assertion) defaultCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Read-only resolved interface
  # ------------------------------------------------------------------------------------------------
  {
    name = "agents.resolved rejects external overrides";
    ok = throws readOnlyMutation.agents.resolved;
  }
]
