# ==================================================================================================
# Supporting Helper Checks
# ==================================================================================================

{
  lib,
  agentsLib,
  harness,
  evalOptionSet,
}:

let
  inherit (harness) check throws;

  # ------------------------------------------------------------------------------------------------
  # Proxy fixtures
  # ------------------------------------------------------------------------------------------------
  proxyStaticCfg = {
    enable = true;
    url = "http://127.0.0.1:8080";
    secretUrlFile = null;
    noProxy = [ "example.com" ];
  };

  proxySecretCfg = {
    enable = true;
    url = "http://ignored.example";
    secretUrlFile = "/run/secrets/proxy-url";
    noProxy = [ ];
  };

  proxyDefaultEval = evalOptionSet (agentsLib.proxy.mkProxyOptions "demo") { };
  proxyStringSecretEval = evalOptionSet (agentsLib.proxy.mkProxyOptions "demo") {
    secretUrlFile = "/run/secrets/proxy-url";
  };

  # ------------------------------------------------------------------------------------------------
  # MCP and prompt fixtures
  # ------------------------------------------------------------------------------------------------
  mcpEnumEval = evalOptionSet (agentsLib.mcp.mkMcpOptions {
    names = [
      "github"
      "gitlab"
    ];
  }) { };

  mcpOpenEval = evalOptionSet (agentsLib.mcp.mkMcpOptions { }) {
    enabledServers = [ "custom-server" ];
  };

  promptFile = ./fixtures/prompt.txt;
  promptRenderer = agentsLib.prompts.mkPromptRenderer {
    "@who@" = "world";
    "@body@\n" = ./fixtures/prompt-fragment.txt;
  };
in
check "lib-helpers" [
  {
    name = "channelIds strips route prefix";
    ok =
      agentsLib.models.channelIds "route/claude-opus-5-5" == [
        "route/claude-opus-5-5"
        "claude-opus-5-5"
      ]
      && agentsLib.models.channelIds "claude-opus-5-5" == [ "claude-opus-5-5" ];
  }
  {
    name = "modelIdFor prefers configured channels and falls back to catalog key";
    ok =
      let
        catalog = agentsLib.models.extendCatalog {
          models."gemini-4-hydrogen".channelId = {
            alpha = "alpha/gemini-4-hydrogen";
            beta = "beta/gemini-4-hydrogen";
          };
        };
      in
      agentsLib.models.modelIdFor [ "beta" ] catalog "gemini-4-hydrogen" == "beta/gemini-4-hydrogen"
      && agentsLib.models.modelIdFor [ ] catalog "gemini-4-hydrogen" == "alpha/gemini-4-hydrogen"
      && agentsLib.models.modelIdFor [ "beta" ] catalog "claude-opus-5-5" == "claude-opus-5-5";
  }
  {
    name = "prompts renderText, renderFile, mkPromptRenderer, and joinSections";
    ok =
      agentsLib.prompts.renderText { "@who@" = "world"; } "hello @who@" == "hello world"
      &&
        agentsLib.prompts.renderFile { "@who@" = "world"; } promptFile
        == "Hello world.\n@body@\n@closing@\n"
      && promptRenderer.readPrompt promptFile == "Hello world.\nA short example.\n@closing@\n"
      &&
        promptRenderer.renderPrompt {
          "@who@" = "reader";
          "@closing@" = "Thank you.";
        } promptFile == "Hello reader.\nA short example.\nThank you.\n"
      && promptRenderer.fragments."@body@\n" == "A short example.\n"
      &&
        agentsLib.prompts.joinSections [
          "a"
          ""
          "  b  "
        ] == "a\n\nb";
  }
  {
    name = "proxy renderNoProxy deduplicates entries";
    ok =
      agentsLib.proxy.renderNoProxy {
        noProxy = [
          "example.com"
          "localhost"
        ];
      } == "localhost,127.0.0.1,10.0.0.0/8,example.com";
  }
  {
    name = "proxy mkProxyScript and mkProxyWrapArgs";
    ok =
      lib.hasInfix "proxy_url=${lib.escapeShellArg "http://127.0.0.1:8080"}" (
        agentsLib.proxy.mkProxyScript proxyStaticCfg
      )
      && lib.hasInfix "if [ -r ${lib.escapeShellArg "/run/secrets/proxy-url"} ]" (
        agentsLib.proxy.mkProxyScript proxySecretCfg
      )
      && !(lib.hasInfix "ignored.example" (agentsLib.proxy.mkProxyScript proxySecretCfg))
      && agentsLib.proxy.mkProxyWrapArgs (proxyStaticCfg // { enable = false; }) == [ ]
      &&
        agentsLib.proxy.mkProxyWrapArgs proxyStaticCfg == [
          "--run"
          (agentsLib.proxy.mkProxyScript proxyStaticCfg)
        ];
  }
  {
    name = "proxy mkProxyOptions defaults and rejects path literals";
    ok =
      !proxyDefaultEval.enable
      && proxyDefaultEval.url == ""
      && proxyDefaultEval.secretUrlFile == null
      && proxyDefaultEval.noProxy == [ ]
      && proxyStringSecretEval.secretUrlFile == "/run/secrets/proxy-url"
      &&
        throws
          (evalOptionSet (agentsLib.proxy.mkProxyOptions "demo") {
            secretUrlFile = ./default.nix;
          }).secretUrlFile;
  }
  {
    name = "mcp computeEnabledServers and mkMcpOptions";
    ok =
      agentsLib.mcp.computeEnabledServers {
        enabledServers = [
          "github"
          "gitlab"
        ];
        disabledServers = [ "gitlab" ];
      } == [ "github" ]
      &&
        mcpEnumEval.enabledServers == [
          "github"
          "gitlab"
        ]
      && mcpEnumEval.disabledServers == [ ]
      && mcpOpenEval.enabledServers == [ "custom-server" ]
      &&
        throws
          (evalOptionSet (agentsLib.mcp.mkMcpOptions { names = [ "github" ]; }) {
            enabledServers = [ "unknown" ];
          }).enabledServers;
  }
]
