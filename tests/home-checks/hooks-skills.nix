# ==================================================================================================
# Model Call, Hooks, and Skills Evaluation Checks
# ==================================================================================================

{
  pkgs,
  lib,
  check,
  throws,
  evalHome,
  homeDirectory,
}:

let
  sampleSkill = pkgs.runCommand "sample-skill" { } ''
    mkdir -p "$out/scripts"
    echo "# Sample" > "$out/SKILL.md"
    echo "echo hi" > "$out/scripts/run.sh"
  '';

  disabledCfg = evalHome {
    agents = {
      modelCall.enable = false;
      skills = {
        targets = {
          claude = true;
          codex = true;
          omp = true;
        };
        sources = {
          untrusted = sampleSkill;
          trusted = {
            source = sampleSkill;
            trustedScripts = [ "scripts/run.sh" ];
          };
        };
      };
    };
  };

  enabledCfg = evalHome {
    agents = {
      models.catalog."gemini-4-flash".channelId = {
        alpha = "alpha/gemini-4-flash";
        beta = "beta/gemini-4-flash";
      };

      modelCall = {
        enable = true;
        baseUrl = "https://gateway.example.test";
        apiKeyFile = "/run/secrets/model-call-key";
        channels = [ "beta" ];
        extraHeaders."x-env" = "test";
      };

      skills = {
        prosePolish.model = "custom/prose-model";
        targets.claude = true;
      };
    };
  };

  missingBaseUrlCfg = evalHome {
    agents.modelCall.enable = true;
  };

  toolClasses = {
    fileWrite = [
      "Edit"
      "Write"
    ];
  };

  disabledHooksFactory = disabledCfg.agents.resolved.mkHooks {
    assistant = "claude-code";
    inherit toolClasses;
  };

  disabledInstalled = disabledHooksFactory.install [
    disabledHooksFactory.hooks.autoFormat
    disabledHooksFactory.hooks.commentGate
    disabledHooksFactory.hooks.completeness
  ];

  enabledHooksFactory = enabledCfg.agents.resolved.mkHooks {
    assistant = "claude-code";
    inherit toolClasses;
  };

  enabledInstalled = enabledHooksFactory.install [
    enabledHooksFactory.hooks.autoFormat
    enabledHooksFactory.hooks.commentGate
    enabledHooksFactory.hooks.completeness
  ];

  disabledSkillScripts = disabledCfg.agents.resolved.mkSkillScriptPaths "${homeDirectory}/.claude/skills";
  enabledSkillScripts = enabledCfg.agents.resolved.mkSkillScriptPaths "${homeDirectory}/.claude/skills";
in
check "home-shared-hooks-skills" [
  # ------------------------------------------------------------------------------------------------
  # modelCall gating for hooks
  # ------------------------------------------------------------------------------------------------
  {
    name = "disabled modelCall filters out commentGate while keeping autoFormat and completeness";
    ok =
      builtins.length disabledInstalled.events.PostToolUse == 1
      && builtins.length disabledInstalled.events.Stop == 1
      && disabledInstalled.dataFiles ? "agents-nix/hooks/claude-code-auto-format"
      && !(disabledInstalled.dataFiles ? "agents-nix/hooks/claude-code-comment-gate");
  }
  {
    name = "enabled modelCall installs both autoFormat and commentGate with stable hook links";
    ok =
      builtins.length enabledInstalled.events.PostToolUse == 2
      && enabledInstalled.dataFiles ? "agents-nix/hooks/claude-code-auto-format"
      && enabledInstalled.dataFiles ? "agents-nix/hooks/claude-code-comment-gate"
      &&
        (builtins.head (builtins.head enabledInstalled.events.PostToolUse).hooks).command
        == "${enabledCfg.agents.dataDir}/hooks/claude-code-auto-format";
  }
  {
    name = "enabled modelCall without baseUrl fails module assertion";
    ok = throws missingBaseUrlCfg.assertions;
  }

  # ------------------------------------------------------------------------------------------------
  # Skills installation and trustedScripts supply-chain guard
  # ------------------------------------------------------------------------------------------------
  {
    name = "disabled modelCall omits prose-polish skill";
    ok = !(disabledCfg.agents.skills.sources ? prose-polish);
  }
  {
    name = "enabled modelCall auto-registers prose-polish skill and its trusted script";
    ok =
      enabledCfg.agents.skills.sources ? prose-polish
      && enabledCfg.agents.skills.prosePolish.model == "custom/prose-model"
      && enabledCfg.agents.modelCall.channels == [ "beta" ]
      && lib.elem "${homeDirectory}/.claude/skills/prose-polish/scripts/prose-polish" enabledSkillScripts
      && lib.all (a: a.assertion) enabledCfg.assertions;
  }
  {
    name = "only skills declaring trustedScripts contribute script-allowlist paths";
    ok = disabledSkillScripts == [ "${homeDirectory}/.claude/skills/trusted/scripts/run.sh" ];
  }
  {
    name = "skills install into enabled claude, codex, and omp targets with expected recursion";
    ok =
      disabledCfg.home.file."${homeDirectory}/.claude/skills/trusted".recursive
      && disabledCfg.home.file."${homeDirectory}/.omp/agent/skills/trusted".recursive
      && !disabledCfg.home.file."${homeDirectory}/.codex/skills/trusted".recursive;
  }
]
