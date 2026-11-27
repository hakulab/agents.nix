# ==================================================================================================
# Codex Model Catalogs
# ==================================================================================================

{
  pkgs,
  lib,
  codexPackage,
}:

profile:

let
  esc = lib.escapeShellArg;

  # ------------------------------------------------------------------------------------------------
  # GPT models
  # ------------------------------------------------------------------------------------------------
  gptDefaults = lib.mapAttrs' (
    _: workload: lib.nameValuePair workload.modelId workload.model.thinking.defaultLevel
  ) profile.workloads;

  slugPrefix = lib.removeSuffix profile.roles.default.modelKey profile.roles.default.modelId;

  # Codex requires its native catalog's capabilities and prompt metadata.
  gptCatalog =
    pkgs.runCommand "codex-${profile.provider}-gpt-models.json"
      {
        nativeBuildInputs = [
          codexPackage
          pkgs.jq
        ];
      }
      ''
        codex debug models --bundled \
          | jq \
            -e \
            --arg prefix ${esc slugPrefix} \
            --argjson defaults ${esc (builtins.toJSON gptDefaults)} \
            '
              .models |= map(
                select(.supported_in_api)
                | .slug |= $prefix + .
                | .default_reasoning_level = ($defaults[.slug] // .default_reasoning_level)
                | if .upgrade then .upgrade.model |= $prefix + . else . end
              )
              | select(.models != [])
            ' \
            >"$out"
      '';

  # ------------------------------------------------------------------------------------------------
  # Custom / non-GPT models
  # ------------------------------------------------------------------------------------------------
  customModelMetadata = {
    models =
      lib.imap0
        (priority: { model, modelId }: {
          inherit priority;
          slug = modelId;
          display_name = model.name;
          description = "${model.name} via ${profile.provider}";
          default_reasoning_level = model.thinking.defaultLevel;
          supported_reasoning_levels = map (effort: {
            inherit effort;
            description = "${effort} reasoning effort";
          }) model.thinking.efforts;
          shell_type = "unified_exec";
          visibility = "list";
          supported_in_api = true;
          include_apps_usage_instructions = false;
          supports_reasoning_summary_parameter = false;
          default_reasoning_summary = "none";
          support_verbosity = false;
          truncation_policy = {
            mode = "bytes";
            limit = 10000;
          };

          context_window = model.contextWindow;
          max_context_window = model.contextWindow;
          auto_compact_token_limit = model.autoCompactTokens;
          experimental_supported_tools = [ ];
          input_modalities = model.input;
        })
        (
          lib.unique (
            map (tier: { inherit (profile.workloads.${tier}) model modelId; }) [
              "flagship"
              "standard"
              "mini"
            ]
          )
        );
  };

  upstreamPromptFile =
    if codexPackage ? src then "${codexPackage.src}/codex-rs/models-manager/prompt.md" else "";

  # Read the upstream prompt at build time to avoid import-from-derivation.
  customCatalog =
    pkgs.runCommand "codex-${profile.provider}-custom-models.json"
      {
        nativeBuildInputs = [
          pkgs.jq
        ];
        modelMetadata = builtins.toJSON customModelMetadata;
        passAsFile = [ "modelMetadata" ];
      }
      ''
        promptFile=${esc upstreamPromptFile}
        if [ -n "$promptFile" ] && [ -f "$promptFile" ]; then
          jq --rawfile instructions "$promptFile" '
            .models |= map(.model_messages = { instructions_template: $instructions })
          ' "$modelMetadataPath" >"$out"
        else
          cp "$modelMetadataPath" "$out"
        fi
      '';
in
if profile.roles.default.family == "gpt" then gptCatalog else customCatalog
