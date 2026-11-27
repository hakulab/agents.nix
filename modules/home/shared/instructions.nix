# ==================================================================================================
# Shared Instructions Module (agents.instructions)
# ==================================================================================================

{
  agentsLib,
  assetsDir,
  devkitOutPath,
  promptFragments,
}:

{
  config,
  lib,
  ...
}:

let
  cfg = config.agents;

  instructionsAssetsDir = assetsDir + "/instructions";
  docsAssetsDir = instructionsAssetsDir + "/docs";
  installedDocsDir = "${cfg.dataDir}/instructions";

  # ------------------------------------------------------------------------------------------------
  # Built-in documents
  # ------------------------------------------------------------------------------------------------
  defaultDocs = {
    "code-design.md" = promptFragments.readPrompt (docsAssetsDir + "/code-design.md");
    "delegation.md" = promptFragments.readPrompt (docsAssetsDir + "/delegation.md");
    "documentation.md" = promptFragments.readPrompt (docsAssetsDir + "/documentation.md");
    "editing-and-comments.md" = promptFragments.readPrompt (docsAssetsDir + "/editing-and-comments.md");
    "mcp-servers.md" = promptFragments.readPrompt (docsAssetsDir + "/mcp-servers.md");
    "terminals-and-workmux.md" = promptFragments.readPrompt (
      docsAssetsDir + "/terminals-and-workmux.md"
    );
    "verification-and-tests.md" = promptFragments.readPrompt (
      docsAssetsDir + "/verification-and-tests.md"
    );
    "writing.md" = promptFragments.readPrompt (docsAssetsDir + "/writing.md");
  };

  renderBase =
    substitutions:
    promptFragments.renderPrompt substitutions (instructionsAssetsDir + "/instructions.md");

  resolvedInstructions = agentsLib.prompts.joinSections [
    cfg.instructions.baseText
    cfg.instructions.extraSections
  ];

  isUnderXdgData = lib.hasPrefix "${config.xdg.dataHome}/" installedDocsDir;
  docsDirXdgRel = lib.removePrefix "${config.xdg.dataHome}/" installedDocsDir;
  docsDirHomeRel = lib.removePrefix "${config.home.homeDirectory}/" installedDocsDir;
in
{
  # ------------------------------------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------------------------------------
  options.agents = {
    instructions = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include the bundled instruction text and install companion guides";
      };

      docs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Companion instruction guide files installed under dataDir/instructions";
      };

      baseText = lib.mkOption {
        type = lib.types.lines;
        default =
          if cfg.instructions.enable then
            renderBase {
              "@devkitSource@" = devkitOutPath;
              "@docsDir@" = installedDocsDir;
            }
          else
            "";
        description = "Base cross-assistant instruction text";
      };

      extraSections = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional instruction sections appended after baseText";
      };
    };

    resolved.instructions = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Resolved cross-assistant instruction text combining baseText and extraSections";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      agents = {
        instructions.docs = lib.mapAttrs (_: lib.mkDefault) defaultDocs;
        resolved.instructions = resolvedInstructions;
      };
    }

    (lib.mkIf (cfg.instructions.enable && isUnderXdgData) {
      xdg.dataFile = lib.mapAttrs' (
        name: text: lib.nameValuePair "${docsDirXdgRel}/${name}" { inherit text; }
      ) cfg.instructions.docs;
    })

    (lib.mkIf (cfg.instructions.enable && !isUnderXdgData) {
      home.file = lib.mapAttrs' (
        name: text: lib.nameValuePair "${docsDirHomeRel}/${name}" { inherit text; }
      ) cfg.instructions.docs;
    })
  ];
}
