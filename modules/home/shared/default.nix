# ==================================================================================================
# Shared Home Manager Module (agents.*)
# ==================================================================================================

{
  agentsLib,
  devkitLib,
  devkitOutPath,
  repoRoot,
  packagesFor,
}:

let
  assetsDir = repoRoot + "/assets";
  scriptsDir = repoRoot + "/scripts";

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
  selfPackages = packagesFor pkgs.stdenv.hostPlatform.system;

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
    (import ./hooks {
      inherit
        devkitLib
        mkNuModules
        packagesFor
        scriptsDir
        ;
    })
    (import ./instructions.nix {
      inherit
        agentsLib
        assetsDir
        devkitOutPath
        ;
    })
    (import ./mcp {
      inherit
        agentsLib
        packagesFor
        ;
    })
    (import ./model-call.nix {
      inherit
        devkitLib
        scriptsDir
        ;
    })
    (import ./notify.nix {
      inherit
        devkitLib
        scriptsDir
        ;
    })
    (import ./permissions.nix {
      inherit agentsLib;
    })
    (import ./profiles {
      inherit
        agentsLib
        devkitLib
        mkNuModules
        scriptsDir
        ;
    })
    (import ./roles {
      inherit assetsDir;
    })
    (import ./skills {
      inherit
        assetsDir
        devkitLib
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

    _internal.configDirs = lib.mkOption {
      type = lib.types.anything;
      internal = true;
    };

    resolved = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "Resolved read-only interface consumed by assistant adapters and external modules";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents = {
    _internal = {
      inherit configDirs;
    };

    resolved = {
      inherit (cfg) dataDir;
      inherit (cfg._internal)
        agentRoleOptions
        agentRoles
        anthropicProfiles
        configDirs
        fileFormatter
        instructionDocs
        instructions
        instructionsDir
        mcp
        mkHooks
        mkModelCall
        mkProfileSwitch
        mkSkillScriptPaths
        modelCatalog
        notify
        permissions
        profileResolver
        promptFragments
        resolveProfiles
        timeouts
        workloadPolicy
        ;
      preferences = {
        askTimeout = 300;
        plansDir = ".agents/plans";
      };
    };
  };
}
