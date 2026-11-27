# ==================================================================================================
# Codex Desktop Preferences
# ==================================================================================================

{
  homeDir,
}:

{
  appearanceDarkChromeTheme = {
    accent = "#0169cc";
    accentSource = "custom";
    contrast = 50;
    fonts = {
      code = "\"Maple Mono NF CN\"";
    };
    ink = "#fcfcfc";
    opaqueWindows = false;
    semanticColors = {
      diffAdded = "#00a240";
      diffRemoved = "#e02e2a";
      skill = "#b06dff";
    };
    surface = "#111111";
  };

  appearanceDarkCodeThemeId = "codex";
  codeFontSize = 14;
  sansFontSize = 14;
  dock-icon-preference = "codex-system";
  selected-avatar-id = "codex";
  avatar-overlay-pet-visible = false;
  usePointerCursors = true;

  composerEnterBehavior = "cmdAlways";
  followUpQueueMode = "steer";

  enabled-reasoning-efforts = [
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
    "ultra"
    "persistent"
  ];

  show-context-window-usage = true;
  agent-usage-reset-enabled = true;
  notifications-sound = "default";

  projectlessWorkspaceRoot = "${homeDir}/Codex";
  hotkey-window-projectless-default-enabled = true;
  open-link-in-target-preference = "in-app-browser";
  browser-show-full-url = true;
  git-pull-request-merge-method = "squash";
  worktree-upstream-refresh-mode = "best-effort";

  preventSleepWhileRunning = true;
  keepRemoteControlAwakeWhilePluggedIn = true;

  external-agent-import-sync-enabled = false;
  external-agent-import-sync-item-types = {
    CONFIG = "original";
    HOOKS = "original";
    MCP_SERVER_CONFIG = "original";
    PLUGINS = "original";
    SESSIONS = "original";
    SKILLS = "original";
  };
}
