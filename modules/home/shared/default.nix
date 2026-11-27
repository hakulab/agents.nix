# ==================================================================================================
# Shared Home Manager Module (agents.*)
# ==================================================================================================

{
  self,
  devkit,
  agentsLib,
}:

let
  assetsDir = ../../../assets;
  scriptsDir = ../../../scripts;

  mkNuModules =
    lib:
    lib.fileset.toSource {
      root = scriptsDir + "/lib";
      fileset = lib.fileset.fileFilter (
        file:
        !(
          lib.hasSuffix ".test.nu" file.name
          || lib.hasSuffix ".stub.nu" file.name
          || lib.hasSuffix ".testlib.nu" file.name
        )
      ) (scriptsDir + "/lib");
    };
in
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents;
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
    })
    (import ./roles {
      inherit assetsDir;
    })
    (import ./permissions.nix {
      inherit agentsLib;
    })

    (import ./profiles {
      inherit agentsLib scriptsDir;
      devkitLib = devkit.lib;
    })
    (import ./model-call.nix {
      inherit scriptsDir;
      devkitLib = devkit.lib;
    })

    (import ./mcp {
      inherit self agentsLib;
    })
    (import ./notify.nix {
      inherit scriptsDir;
      devkitLib = devkit.lib;
    })
    (import ./hooks {
      inherit self scriptsDir;
      devkitLib = devkit.lib;
    })
    (import ./skills {
      inherit assetsDir;
      devkitLib = devkit.lib;
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

    resolved = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Resolved read-only interface consumed by assistant adapters and external modules";
    };

    _internal = {
      configDirs = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      nuModules = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents = {
    _internal = {
      inherit configDirs;
      nuModules = mkNuModules lib;
    };

    resolved = {
      inherit (cfg) dataDir;
      inherit (cfg._internal) configDirs;
      preferences = {
        askTimeout = 300;
        plansDir = ".agents/plans";
      };

      inherit (cfg._internal)
        instructionDocs
        instructions
        instructionsDir
        promptFragments
        agentRoleOptions
        agentRoles
        permissions
        ;

      inherit (cfg._internal)
        modelCatalog
        workloadPolicy
        profileResolver
        resolveProfiles
        anthropicProfiles
        mkProfileSwitch
        mkModelCall
        ;

      inherit (cfg._internal)
        mcp
        notify
        fileFormatter
        mkHooks
        timeouts
        mkSkillScriptPaths
        ;
    };
  };
}
