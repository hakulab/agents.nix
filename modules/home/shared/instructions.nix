# ==================================================================================================
# Shared Instructions Module (agents.instructions)
# ==================================================================================================

{
  agentsLib,
  assetsDir,
  devkitOutPath,
}:

{
  config,
  lib,
  ...
}:

let
  cfg = config.agents;

  fragmentsDir = assetsDir + "/prompt-fragments";
  instructionsDir = assetsDir + "/instructions";
  docsDir = instructionsDir + "/docs";

  # ------------------------------------------------------------------------------------------------
  # Prompt fragments and built-in documents
  # ------------------------------------------------------------------------------------------------
  renderer = agentsLib.prompts.mkPromptRenderer {
    "@comments@\n" = fragmentsDir + "/comments.md";
    "@phrasing@\n" = fragmentsDir + "/phrasing.md";
    "@proseTics@\n" = fragmentsDir + "/prose-tics.md";
    "@readOnly@\n" = fragmentsDir + "/read-only.md";
  };

  promptFragments = {
    inherit (renderer) fragments renderPrompt readPrompt;
    phrasing = renderer.fragments."@phrasing@\n";
    roleSections = {
      preamble = builtins.readFile (fragmentsDir + "/preamble.md");
      memory = builtins.readFile (fragmentsDir + "/memory.md");
      coordination = builtins.readFile (fragmentsDir + "/coordination.md");
      status = builtins.readFile (fragmentsDir + "/status.md");
    };
  };

  defaultDocs = {
    "code-design.md" = promptFragments.readPrompt (docsDir + "/code-design.md");
    "delegation.md" = promptFragments.readPrompt (docsDir + "/delegation.md");
    "documentation.md" = promptFragments.readPrompt (docsDir + "/documentation.md");
    "editing-and-comments.md" = promptFragments.readPrompt (docsDir + "/editing-and-comments.md");
    "mcp-servers.md" = promptFragments.readPrompt (docsDir + "/mcp-servers.md");
    "terminals-and-workmux.md" = promptFragments.readPrompt (docsDir + "/terminals-and-workmux.md");
    "verification-and-tests.md" = promptFragments.readPrompt (docsDir + "/verification-and-tests.md");
    "writing.md" = promptFragments.readPrompt (docsDir + "/writing.md");
  };

  renderBase =
    substitutions: promptFragments.renderPrompt substitutions (instructionsDir + "/instructions.md");

  resolvedInstructions = agentsLib.prompts.joinSections [
    cfg.instructions.baseText
    cfg.instructions.extraSections
  ];

  isUnderXdgData = lib.hasPrefix "${config.xdg.dataHome}/" cfg.instructions.docsDir;
  docsDirXdgRel = lib.removePrefix "${config.xdg.dataHome}/" cfg.instructions.docsDir;
  docsDirHomeRel = lib.removePrefix "${config.home.homeDirectory}/" cfg.instructions.docsDir;
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
        description = "Install shared agent instruction documents";
      };

      docsDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/instructions";
        description = "Directory where companion instruction guides are installed";
      };

      docs = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Companion instruction guide files installed under docsDir";
      };

      extraLinks = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Placeholder substitutions applied when rendering baseText";
      };

      baseText = lib.mkOption {
        type = lib.types.lines;
        default = renderBase (
          cfg.instructions.extraLinks
          // {
            "@docsDir@" = cfg.instructions.docsDir;
          }
        );
        description = "Base cross-assistant instruction text";
      };

      extraSections = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional instruction sections appended after baseText";
      };
    };

    _internal = {
      instructionDocs = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      instructions = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      instructionsDir = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };

      promptFragments = lib.mkOption {
        type = lib.types.anything;
        internal = true;
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      agents = {
        instructions = {
          docs = lib.mapAttrs (_: lib.mkDefault) defaultDocs;
          extraLinks."@devkitSource@" = lib.mkDefault devkitOutPath;
        };

        _internal = {
          inherit promptFragments;
          instructionDocs = cfg.instructions.docs;
          instructions = resolvedInstructions;
          instructionsDir = cfg.instructions.docsDir;
        };
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
