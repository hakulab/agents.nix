# ==================================================================================================
# Shared Hooks Module (agents.hooks)
# ==================================================================================================

{
  devkitLib,
  mkNuModules,
  packagesFor,
  scriptsDir,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents;
  internal = cfg._internal;
  dk = devkitLib.mkLib pkgs;
  selfPackages = packagesFor pkgs.stdenv.hostPlatform.system;
  nuModules = mkNuModules lib;

  json = pkgs.formats.json { };

  fileFormatter = lib.getExe cfg.hooks.fileFormatterPackage;
  resolvedTimeouts = cfg.modelCall.timeouts // cfg.hooks.timeouts;

  patchInput = lib.getExe (
    dk.writeNuApplication {
      name = "patch-input";
      text = builtins.readFile (scriptsDir + "/lib/patch-input.nu");
      runtimeInputs = [ pkgs.coreutils ];
    }
  );

  handlerFields = [
    "type"
    "command"
    "prompt"
    "timeout"
    "statusMessage"
    "async"
  ];

  # ------------------------------------------------------------------------------------------------
  # Hook factory
  # ------------------------------------------------------------------------------------------------
  # Codex trusts a hook by hashing its event, matcher, and handler, command included. Commands name
  # stable links, which each activation updates, so a rebuild that changes only a script keeps the
  # hook's hash.
  dataPrefix = lib.removePrefix "${config.xdg.dataHome}/" cfg.dataDir;

  mkHooks =
    {
      assistant,
      toolClasses,
      enableModelCall ? cfg.modelCall.enable,
    }:
    let
      mkNuHook =
        {
          slug,
          script,
          runtimeInputs ? [ ],
          config ? null,
        }:
        let
          name = "${assistant}-${slug}";
        in
        lib.getExe (
          dk.writeNuApplication {
            inherit name;
            text = builtins.readFile script;
            runtimeInputs = [ pkgs.coreutils ] ++ runtimeInputs;
            libDirs = [ nuModules ];
            flags = lib.optionalAttrs (config != null) {
              config = json.generate "${name}.json" config;
            };
          }
        );

      modelCall = internal.mkModelCall {
        inherit assistant;
      };

      mkMatcher =
        tools: lib.concatStringsSep "|" (lib.unique (lib.concatMap (tool: toolClasses.${tool}) tools));

      mkEntry =
        hook:
        lib.optionalAttrs (hook ? matcher) { inherit (hook) matcher; }
        // lib.optionalAttrs (hook ? tools) { matcher = mkMatcher hook.tools; }
        // {
          hooks = [ (lib.filterAttrs (name: _: lib.elem name handlerFields) hook) ];
        };

      install =
        requested:
        let
          hooks = lib.filter (hook: (hook.usesModelCall or false) -> enableModelCall) requested;
          commandHooks = lib.filter (hook: hook.type == "command") hooks;
          link = hook: "${dataPrefix}/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
          linked = map (
            hook:
            if hook.type == "command" then
              hook
              // {
                command = "${cfg.dataDir}/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
              }
            else
              hook
          ) hooks;
        in
        {
          events = lib.mapAttrs (_: map mkEntry) (lib.groupBy (hook: hook.event) linked);

          dataFiles = lib.listToAttrs (
            map (hook: lib.nameValuePair (link hook) { source = hook.command; }) commandHooks
          );
        };
    in
    {
      inherit
        install
        mkNuHook
        ;
      timeouts = resolvedTimeouts;

      hooks = {
        autoFormat = import ./auto-format.nix {
          inherit
            scriptsDir
            mkNuHook
            fileFormatter
            patchInput
            ;
          timeouts = resolvedTimeouts;
        };

        commentGate = import ./comment-gate.nix {
          inherit
            scriptsDir
            mkNuHook
            modelCall
            patchInput
            ;
          inherit (internal) modelCatalog modelIdFor promptFragments;
          modelCallCfg = cfg.modelCall;
          timeouts = resolvedTimeouts;
        };

        completeness = import ./completeness.nix {
          inherit scriptsDir;
          timeouts = resolvedTimeouts;
        };
      };
    };
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    _internal = {
      fileFormatter = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      mkHooks = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      timeouts = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };

    hooks = {
      fileFormatterPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.file-formatter or selfPackages.file-formatter;
        description = "File formatter package invoked by post-edit formatting hooks";
      };

      timeouts = {
        postEdit = lib.mkOption {
          type = lib.types.int;
          default = 120;
          description = "Timeout in seconds for post-edit formatting hooks";
        };

        tool = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Timeout in seconds for lightweight tool hooks";
        };
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config.agents._internal = {
    inherit
      fileFormatter
      mkHooks
      ;
    timeouts = resolvedTimeouts;
  };
}
