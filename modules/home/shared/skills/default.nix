# ==================================================================================================
# Shared Skills Module (agents.skills)
# ==================================================================================================

{
  agentsLib,
  assetsDir,
  devkitLib,
  promptFragments,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents;
  inherit (cfg) resolved;
  dk = devkitLib.mkLib pkgs;
  modelIdFor = agentsLib.models.modelIdFor cfg.modelCall.channels;

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  skillSourceSubmodule = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.either lib.types.path lib.types.str;
        description = "Directory path or derivation providing the skill files";
      };

      trustedScripts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Relative script paths inside this skill allowed to run without prompting";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Built-in skills
  # ------------------------------------------------------------------------------------------------
  prosePolishSkill = import ./prose-polish.nix {
    inherit
      pkgs
      lib
      dk
      assetsDir
      ;
    inherit (resolved) modelCatalog;
    inherit modelIdFor promptFragments;
    modelCall = cfg.modelCall.mkCall {
      assistant = "prose-polish";
      timeout = 300;
    };
    modelOverride = cfg.skills.prosePolish.model;
  };

  # ------------------------------------------------------------------------------------------------
  # Skill normalization and installation
  # ------------------------------------------------------------------------------------------------
  normalizeSkillEntry =
    entry:
    if builtins.isAttrs entry && !(lib.isDerivation entry) && entry ? source then
      entry
    else
      {
        source = entry;
        trustedScripts = [ ];
      };

  normalizedSkills = lib.mapAttrs (_: normalizeSkillEntry) cfg.skills.sources;

  skillScripts = lib.concatLists (
    lib.mapAttrsToList (
      skill: entry: map (file: { inherit skill file; }) entry.trustedScripts
    ) normalizedSkills
  );

  mkSkillScriptPaths =
    skillsDir: map (script: "${skillsDir}/${script.skill}/${script.file}") skillScripts;

  mkSkillFiles =
    { directory, recursive }:
    lib.mapAttrs' (
      name: entry:
      lib.nameValuePair "${directory}/${name}" {
        inherit (entry) source;
        inherit recursive;
      }
    ) normalizedSkills;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    skills = {
      sources = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either (lib.types.either lib.types.path lib.types.str) skillSourceSubmodule
        );
        default = { };
        description = "Skill directories installed into enabled assistant targets";
      };

      targets = {
        claude = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install skills into the Claude Code skills directory";
        };

        codex = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install skills into the Codex skills directory";
        };

        omp = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install skills into the Oh My Pi skills directory";
        };

        agy = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Install skills into the Antigravity skills directory";
        };
      };

      prosePolish = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = cfg.modelCall.enable;
          description = "Install the built-in prose-polish skill when modelCall is enabled";
        };

        model = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override model ID used by the prose-polish skill";
        };
      };
    };

    resolved.mkSkillScriptPaths = lib.mkOption {
      type = lib.types.anything;
      internal = true;
      readOnly = true;
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      agents = {
        skills.sources = lib.mkIf (cfg.skills.prosePolish.enable && cfg.modelCall.enable) {
          prose-polish = lib.mkDefault {
            source = prosePolishSkill;
            trustedScripts = prosePolishSkill.scripts;
          };
        };

        resolved = {
          inherit mkSkillScriptPaths;
        };
      };
    }

    (lib.mkIf cfg.skills.targets.claude {
      home.file = mkSkillFiles {
        directory = "${resolved.configDirs.claude}/skills";
        recursive = true;
      };
    })

    (lib.mkIf cfg.skills.targets.codex {
      home.file = mkSkillFiles {
        directory = "${resolved.configDirs.codex}/skills";
        recursive = false;
      };
    })

    (lib.mkIf cfg.skills.targets.omp {
      home.file = mkSkillFiles {
        directory = "${resolved.configDirs.omp}/skills";
        recursive = true;
      };
    })

    (lib.mkIf cfg.skills.targets.agy {
      home.file = mkSkillFiles {
        directory = "${resolved.configDirs.agy}/skills";
        recursive = false;
      };
    })
  ];
}
