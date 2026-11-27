# ==================================================================================================
# Shared Home Manager Module (agents.*)
# ==================================================================================================

{
  self,
  devkit,
  agentsLib,
  nuModules,
  repoRoot,
}:

let
  devkitLib = devkit.lib;
  assetsDir = repoRoot + "/assets";
  scriptsDir = repoRoot + "/scripts";
  fragmentsDir = assetsDir + "/prompt-fragments";

  renderer = agentsLib.prompts.mkPromptRenderer {
    "@comments@\n" = fragmentsDir + "/comments.md";
    "@phrasing@\n" = fragmentsDir + "/phrasing.md";
    "@proseTics@\n" = fragmentsDir + "/prose-tics.md";
    "@readOnly@\n" = fragmentsDir + "/read-only.md";
  };

  promptFragments = {
    inherit (renderer) renderPrompt readPrompt;
    phrasing = renderer.fragments."@phrasing@\n";
    roleSections = {
      preamble = builtins.readFile (fragmentsDir + "/preamble.md");
      memory = builtins.readFile (fragmentsDir + "/memory.md");
      coordination = builtins.readFile (fragmentsDir + "/coordination.md");
      status = builtins.readFile (fragmentsDir + "/status.md");
    };
  };
in
{
  config,
  pkgs,
  lib,
  ...
}:

let
  selfPackages = self.packages.${pkgs.stdenv.hostPlatform.system};

  configDirs = {
    claude = "${config.home.homeDirectory}/.claude";

    codex =
      if config.home.preferXdgDirectories then
        "${config.xdg.configHome}/codex"
      else
        "${config.home.homeDirectory}/.codex";

    omp = "${config.home.homeDirectory}/.omp/agent";
  };
in
{
  key = "agents-nix/home/shared";

  imports = [
    (import ./instructions.nix {
      inherit agentsLib assetsDir;
      devkitOutPath = devkit.outPath;
      inherit promptFragments;
    })
    (import ./roles {
      inherit assetsDir promptFragments;
    })
    (import ./permissions.nix {
      inherit agentsLib;
    })

    (import ./profiles {
      inherit
        agentsLib
        devkitLib
        nuModules
        scriptsDir
        ;
    })
    (import ./model-call.nix {
      inherit devkitLib scriptsDir;
    })

    (import ./mcp {
      inherit self agentsLib;
    })
    (import ./notify.nix {
      inherit devkitLib scriptsDir;
    })
    (import ./hooks {
      inherit
        self
        devkitLib
        agentsLib
        nuModules
        promptFragments
        scriptsDir
        ;
    })
    (import ./skills {
      inherit
        agentsLib
        assetsDir
        devkitLib
        promptFragments
        ;
    })
  ];

  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/agents-nix";
      description = "Base directory for agents.nix runtime data such as instructions and hooks";
    };

    proxy = agentsLib.proxy.mkProxyOptions "coding agents";

    browser = {
      chromiumPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = (pkgs.browser-tools or selfPackages.browser-tools).chromium;
        description = "Chromium package used by browser-backed MCP servers and assistants";
      };
    };

    resolved = {
      configDirs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        description = "Resolved per-assistant configuration directory paths";
      };

      preferences = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        readOnly = true;
        description = "Resolved shared assistant preferences such as askTimeout and plansDir";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents.resolved = {
    inherit configDirs;
    preferences = {
      askTimeout = 300;
      plansDir = ".agents/plans";
    };
  };
}
