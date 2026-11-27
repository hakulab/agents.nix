# ==================================================================================================
# Claude Code Home Manager Evaluation Checks
# ==================================================================================================

{
  lib,
  harness,
  fixtures,
}:

let
  inherit (harness) check throws homeDirectory;

  inherit (fixtures)
    disabledCfg
    standaloneEnabledCfg
    combinedEnabledCfg
    fullCfg
    minimalHooksAndNoStatuslineCfg
    edgeCasesCfg
    missingBaseUrlProfileCfg
    unknownOverrideProfileCfg
    disabledOverrideProfileCfg
    invalidEnvNameProfileCfg
    unknownMcpCfg
    ;

  hasFailingAssertion = cfg: throws cfg.assertions;
in
check "home-claude-code" [
  # ------------------------------------------------------------------------------------------------
  # Default disabled state
  # ------------------------------------------------------------------------------------------------
  {
    name = "disabled by default without enabling programs.claude-code or claude-statusline";
    ok =
      !disabledCfg.agents.claude-code.enable
      && !disabledCfg.programs.claude-code.enable
      && !disabledCfg.programs.claude-statusline.enable
      && !disabledCfg.agents.skills.targets.claude
      && !(disabledCfg.home.file ? ".claude/settings.json")
      && !(disabledCfg.home.file ? ".claude/CLAUDE.md")
      && lib.all (a: a.assertion) disabledCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Standalone and combined imports, packages, and instructions
  # ------------------------------------------------------------------------------------------------
  {
    name = "standalone import provides default upstream packages and enables claude-code";
    ok =
      standaloneEnabledCfg.programs.claude-code.enable
      && standaloneEnabledCfg.programs.claude-statusline.enable
      && standaloneEnabledCfg.agents.skills.targets.claude
      && lib.isDerivation standaloneEnabledCfg.agents.claude-code.package
      && lib.isDerivation standaloneEnabledCfg.agents.claude-code.hooks.worktree.workmuxPackage
      && lib.isDerivation standaloneEnabledCfg.agents.claude-code.statusline.package
      && lib.all (a: a.assertion) standaloneEnabledCfg.assertions;
  }
  {
    name = "importing sharedModule and claudeCodeModule together deduplicates cleanly";
    ok =
      combinedEnabledCfg.programs.claude-code.enable
      && combinedEnabledCfg.home.file ? ".claude/settings.json"
      && combinedEnabledCfg.home.file ? ".claude/CLAUDE.md"
      && combinedEnabledCfg.home.file ? ".claude/agents"
      && lib.all (a: a.assertion) combinedEnabledCfg.assertions;
  }
  {
    name = "CLAUDE.md includes shared instructions, Claude Code addendum, and extraInstructions";
    ok =
      let
        text = fullCfg.home.file.".claude/CLAUDE.md".text;
      in
      lib.hasInfix fullCfg.agents.resolved.instructions text
      && lib.hasInfix "## Claude Code" text
      && lib.hasInfix "## Local Notes" text;
  }

  # ------------------------------------------------------------------------------------------------
  # Hooks and data files
  # ------------------------------------------------------------------------------------------------
  {
    name = "default enabled hooks omit comment-gate when modelCall is disabled";
    ok =
      combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-dream"
      && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-format"
      && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-teammate-idle"
      && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-create"
      && combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-remove"
      && !(combinedEnabledCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-comment-gate");
  }
  {
    name = "enabled modelCall installs comment-gate hook alongside default hooks";
    ok = fullCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-comment-gate";
  }
  {
    name = "disabling all hooks installs no hook dataFiles";
    ok =
      !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-dream")
      && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-auto-format")
      && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-teammate-idle")
      && !(minimalHooksAndNoStatuslineCfg.xdg.dataFile ? "agents-nix/hooks/claude-code-worktree-create")
      && !minimalHooksAndNoStatuslineCfg.programs.claude-statusline.enable
      && lib.all (a: a.assertion) minimalHooksAndNoStatuslineCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Profiles, statusline, and platform paths
  # ------------------------------------------------------------------------------------------------
  {
    name = "profiles install official, gateway anthropic, gateway non-anthropic, and oauth-token bundles";
    ok =
      let
        profilesPrefix = "${fullCfg.xdg.stateHome}/claude-code/profiles";
      in
      fullCfg.home.file ? "${profilesPrefix}/official.d"
      && fullCfg.home.file ? "${profilesPrefix}/gw-claude.d"
      && fullCfg.home.file ? "${profilesPrefix}/gw-alt.d"
      && fullCfg.home.file ? "${profilesPrefix}/official-token.d"
      && lib.all (a: a.assertion) fullCfg.assertions;
  }
  {
    name = "profile switcher package, activation entry, and stateDir follow platform homeDirectory";
    ok =
      lib.any (pkg: (pkg.name or "") == "claude-switch") fullCfg.home.packages
      && fullCfg.home.activation ? claudeCodeProfile
      && lib.hasPrefix "${homeDirectory}/" fullCfg.xdg.stateHome;
  }
  {
    name = "statusline populates catalog models, channelIds, custom models, costSources, and recursive extraSettings";
    ok =
      let
        s = fullCfg.programs.claude-statusline.settings;
      in
      fullCfg.programs.claude-statusline.enable
      && s.models.claude-opus-5-5 == "Claude Opus 5.5"
      && s.models."gw/claude-opus-5-5" == "Claude Opus 5.5"
      && s.models.custom-model == "Custom Model"
      && s.models.extra-model == "Extra Model"
      && builtins.length s.cost_sources == 1
      && (builtins.head s.cost_sources).id == "demo-cost"
      && s.refresh_interval == 30;
  }

  # ------------------------------------------------------------------------------------------------
  # Plugins, MCP, and profile edge cases
  # ------------------------------------------------------------------------------------------------
  {
    name = "custom plugin entries merge with built-in defaults and gate workmux plugin on workmux.enable";
    ok =
      let
        p = fullCfg.agents.claude-code.plugins;
      in
      p.marketplaces ? claude-plugins-official
      && !(p.marketplaces ? workmux)
      && p.marketplaces ? custom-mkt
      && p.enabled."skill-creator@claude-plugins-official"
      && !(p.enabled ? "workmux-status@workmux")
      && p.enabled."custom-plugin@custom-mkt";
  }
  {
    name = "per-assistant disabledServers extends global disabledServers and enabledProfiles filters bundles";
    ok =
      let
        profilesPrefix = "${edgeCasesCfg.xdg.stateHome}/claude-code/profiles";
      in
      lib.elem "deepwiki" edgeCasesCfg.agents.claude-code.mcp.disabledServers
      && lib.elem "gitlab" edgeCasesCfg.agents.claude-code.mcp.disabledServers
      && !(edgeCasesCfg.home.file ? "${profilesPrefix}/official.d")
      && !(edgeCasesCfg.home.file ? "${profilesPrefix}/filtered-out.d")
      && edgeCasesCfg.home.file ? "${profilesPrefix}/custom.d"
      && lib.all (a: a.assertion) edgeCasesCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Assertions and validation
  # ------------------------------------------------------------------------------------------------
  {
    name = "api-key profile without baseUrl fails assertion";
    ok = hasFailingAssertion missingBaseUrlProfileCfg;
  }
  {
    name = "profileOverrides referencing unknown profile fails assertion";
    ok = hasFailingAssertion unknownOverrideProfileCfg;
  }
  {
    name = "profileOverrides referencing disabled profile fails assertion";
    ok = hasFailingAssertion disabledOverrideProfileCfg;
  }
  {
    name = "non-POSIX extraEnv key in profileOverrides fails assertion";
    ok = hasFailingAssertion invalidEnvNameProfileCfg;
  }
  {
    name = "unknown MCP server in enabledServers fails assertion";
    ok = hasFailingAssertion unknownMcpCfg;
  }
]
