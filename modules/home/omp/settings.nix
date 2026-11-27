# ==================================================================================================
# OMP Settings
# ==================================================================================================

{
  resolved,
}:

let
  researcherWorkload = resolved.agentRoles.researcher.workload or "standard";
  reviewerWorkload = resolved.agentRoles.reviewer.workload or "flagship";
in
{
  # ------------------------------------------------------------------------------------------------
  # Appearance
  # ------------------------------------------------------------------------------------------------
  symbolPreset = "nerd";
  composer.shape = "band";
  theme.dark = "titanium";

  statusLine = {
    preset = "custom";

    leftSegments = [
      "model"
      "mode"
      "subagents"
      "path"
      "git"
    ];

    rightSegments = [
      "context_pct"
      "cost"
      "token_rate"
    ];

    separator = "pipe";
    compactThinkingLevel = false;
    sessionAccent = false;
    transparent = true;

    segmentOptions = {
      model.showThinkingLevel = true;

      path = {
        abbreviate = true;
        maxLength = 28;
        stripWorkPrefix = true;
      };

      git = {
        showBranch = true;
        showStaged = true;
        showUnstaged = true;
        showUntracked = true;
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Interaction
  # ------------------------------------------------------------------------------------------------
  startup = {
    checkUpdate = false;
    setupWizard = false;
  };

  personality = "none";

  followUpMode = "all";
  steeringMode = "all";

  ask.timeout = resolved.preferences.askTimeout;

  # ------------------------------------------------------------------------------------------------
  # Providers
  # ------------------------------------------------------------------------------------------------
  providers = {
    cacheRetention = "long";
    streamFirstEventTimeoutSeconds = 1800;
    streamIdleTimeoutSeconds = 0;
    tts = "local";
    webSearchOrder = [
      "exa"
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # Plan
  # ------------------------------------------------------------------------------------------------
  plan.autosaveDir = resolved.preferences.plansDir;

  # ------------------------------------------------------------------------------------------------
  # Memory
  # ------------------------------------------------------------------------------------------------
  checkpoint.enabled = true;
  memory.backend = "local";
  autolearn.enabled = true;

  # ------------------------------------------------------------------------------------------------
  # Agents
  # ------------------------------------------------------------------------------------------------
  advisor = {
    enabled = true;
    maxNotesPerUpdate = 2;
    syncBacklog = "3";
  };

  task = {
    agentModelOverrides = {
      scout = "@${researcherWorkload}";
      security-reviewer = "@${reviewerWorkload}";
      sonic = "@standard";
      task = "@task";
    };

    eager = "preferred";
    enableEffort = true;
    enableLsp = true;
    maxConcurrency = 8;
    maxRecursionDepth = 3;
    maxRuntimeMs = 1800000;

    isolation.enabled = true;
  };

  # ------------------------------------------------------------------------------------------------
  # Editing
  # ------------------------------------------------------------------------------------------------
  astGrep.enabled = true;
  lsp.diagnosticsOnEdit = true;
  github.enabled = true;

  # ------------------------------------------------------------------------------------------------
  # Speech
  # ------------------------------------------------------------------------------------------------
  speechgen.enabled = true;

  # ------------------------------------------------------------------------------------------------
  # Privacy
  # ------------------------------------------------------------------------------------------------
  secrets.enabled = true;
}
