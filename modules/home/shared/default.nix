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

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.agents;
  dk = devkitLib.mkLib pkgs;
  selfPackages = packagesFor pkgs.stdenv.hostPlatform.system;

  assetsDir = repoRoot + "/assets";
  scriptsDir = repoRoot + "/scripts";

  nuRuntimeFiles = lib.fileset.fileFilter (
    file:
    !(
      lib.hasSuffix ".test.nu" file.name
      || lib.hasSuffix ".stub.nu" file.name
      || lib.hasSuffix ".testlib.nu" file.name
    )
  ) (scriptsDir + "/lib");

  nuModules = lib.fileset.toSource {
    root = scriptsDir + "/lib";
    fileset = nuRuntimeFiles;
  };

  # ------------------------------------------------------------------------------------------------
  # Submodule types
  # ------------------------------------------------------------------------------------------------
  roleSubmodule = lib.types.submodule {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        description = "Short description of when to delegate to this role";
      };

      prompt = lib.mkOption {
        type = lib.types.lines;
        description = "System prompt text for this agent role";
      };

      workload = lib.mkOption {
        type = lib.types.enum [
          "default"
          "flagship"
          "standard"
          "mini"
          "prose"
        ];
        default = "standard";
        description = "Workload tier selected for this role";
      };

      claude = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Claude Code-specific role fields";
      };

      codex = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Codex-specific role fields";
      };

      omp = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Oh My Pi-specific role fields";
      };
    };
  };

  channelSubmodule = lib.types.submodule {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = {
      family = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Model family served on this provider channel";
      };

      nativeWebSearch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this channel supports native web search";
      };
    };
  };

  providerSubmodule = lib.types.submodule {
    options = {
      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default base URL for this provider";
      };

      apiUrls = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-API endpoint URLs (e.g. anthropic-messages, openai-responses)";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing the default API key";
      };

      clientApiKeyFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-client runtime API key file paths overriding apiKeyFile";
      };

      caCertFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path to a custom CA certificate bundle";
      };

      extraHeaders = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra HTTP headers sent to this provider";
      };

      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra static environment variables exported for this provider";
      };

      extraEnvFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables loaded from runtime file paths";
      };

      wireApi = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default wire API protocol for this provider";
      };

      channels = lib.mkOption {
        type = lib.types.attrsOf channelSubmodule;
        default = { };
        description = "Provider channels and their capabilities";
      };
    };
  };

  profileSubmodule = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Provider name from agents.providers, or null for an official subscription";
      };

      oauthTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing an OAuth token for subscription auth";
      };

      family = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Model family selected by this profile";
      };

      channel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit provider channel pinned for this profile";
      };

      defaultsKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override key in modelCatalog.defaults used to look up tier models";
      };

      proseModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Explicit model key used for the prose workload";
      };

      nativeWebSearch = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Override whether native web search is enabled for this profile";
      };

      clients = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Optional allowlist of assistant names that receive this profile";
      };
    };
  };

  mcpServerSubmodule = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether this MCP server is enabled";
        };

        type = lib.mkOption {
          type = lib.types.enum [
            "stdio"
            "http"
          ];
          default = "stdio";
          description = "MCP transport type";
        };

        displayName = lib.mkOption {
          type = lib.types.str;
          default = agentsLib.mcp.presetDisplayNames.${name} or name;
          description = "Display name used in permission rules";
        };

        command = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Command and arguments for stdio MCP servers";
        };

        url = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Endpoint URL for HTTP MCP servers";
        };

        envVars = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Static environment variables exported by the server wrapper";
        };

        envFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Runtime file paths read into environment variables on launch";
        };

        setup = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Shell snippet run before executing the stdio command";
        };

        clearProxy = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Clear HTTP(S) proxy environment variables before launching the server";
        };

        runtime = lib.mkOption {
          type = lib.types.enum [
            "direct"
            "npx"
            "uvx"
          ];
          default = "direct";
          description = "Launcher runtime for stdio MCP servers";
        };

        permissions = {
          allowTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "MCP tool names allowed without prompting for this server";
          };

          gateTools = lib.mkOption {
            type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
            default = [ ];
            description = "MCP tool gate entries registered for this server";
          };
        };
      };
    }
  );

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
  # Built-in assets and defaults
  # ------------------------------------------------------------------------------------------------
  instructionAssets = import ./instructions.nix {
    inherit agentsLib assetsDir;
  };

  inherit (instructionAssets) promptFragments;

  roleAssets = import ./agent-roles.nix {
    inherit lib assetsDir promptFragments;
  };

  defaultToasty =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
      pkgs.runCommand "toasty" { } ''
        install -Dm0755 ${
          pkgs.fetchurl {
            url = "https://github.com/shanselman/toasty/releases/download/v0.8.1/toasty-x64.exe";
            hash = "sha256-HGx6JBXNkqEUjPngj9LoX6SOq1dSzj1+D9wfjqH6LaI=";
          }
        } "$out/bin/toasty.exe"
      ''
    else
      null;

  # ------------------------------------------------------------------------------------------------
  # Resolved values
  # ------------------------------------------------------------------------------------------------
  configDirs = {
    claude = "${config.home.homeDirectory}/.claude";

    codex =
      if config.home.preferXdgDirectories then
        "${config.xdg.configHome}/codex"
      else
        "${config.home.homeDirectory}/.codex";

    omp = "${config.home.homeDirectory}/.omp/agent";
  };

  resolvedInstructions = agentsLib.prompts.joinSections [
    cfg.instructions.baseText
    cfg.instructions.extraSections
  ];

  agentRoles = roleAssets.normalizeRoles cfg.roles.definitions;

  agentRoleOptions = roleAssets.mkRoleOptions {
    inherit agentRoles;
    inherit (cfg.roles) defaultEnabled;
  };

  resolvedModelCatalog = agentsLib.models.extendCatalog {
    models = cfg.models.catalog;
    defaults = cfg.models.defaults;
  };

  resolvedWorkloadPolicy = lib.recursiveUpdate agentsLib.models.workloadPolicy cfg.models.workloadPolicy;

  profileResolver = agentsLib.profiles.mkResolver {
    modelCatalog = resolvedModelCatalog;
    workloadPolicy = resolvedWorkloadPolicy;
    inherit (cfg) providers;
  };

  resolveProfiles = args: profileResolver.resolveProfiles ({ inherit (cfg) profiles; } // args);

  anthropicProfiles = import ./anthropic-profiles.nix {
    inherit lib agentsLib;
    inherit (cfg) providers;
  };

  mkProfileSwitch = import ./profile-switch.nix {
    inherit
      pkgs
      lib
      dk
      scriptsDir
      nuModules
      ;
  };

  mcpResult = import ./mcp.nix {
    inherit pkgs lib agentsLib;
    mcpCfg = cfg.mcp;
  };

  mergeMcpAttrs = lib.zipAttrsWith (_: lib.concatLists);

  serverMcpAllows = lib.filterAttrs (_: tools: tools != [ ]) (
    lib.mapAttrs (_: server: server.permissions.allowTools) (
      lib.filterAttrs (_: server: server.enable) cfg.mcp.servers
    )
  );

  serverMcpGates = lib.filterAttrs (_: gates: gates != [ ]) (
    lib.mapAttrs (_: server: server.permissions.gateTools) (
      lib.filterAttrs (_: server: server.enable) cfg.mcp.servers
    )
  );

  resolvedPermissions = agentsLib.permissions.mkPolicy {
    inherit (cfg.permissions) ownRepositories;
    extraServerDisplayNames = mcpResult.displayNames;
    extraAllowCommands = cfg.permissions.allowCommands;
    extraGateCommands = cfg.permissions.gateCommands;
    extraMcpAllows = mergeMcpAttrs [
      cfg.permissions.mcpAllows
      serverMcpAllows
    ];
    extraMcpGates = mergeMcpAttrs [
      cfg.permissions.mcpGates
      serverMcpGates
    ];
    extraAllowPolicies = cfg.permissions.allowPolicies;
    extraGatePolicies = cfg.permissions.gatePolicies;
  };

  resolvedTimeouts = cfg.modelCall.timeouts // cfg.hooks.timeouts;

  fileFormatter = lib.getExe cfg.hooks.fileFormatterPackage;

  mkModelCall = import ./model-call.nix {
    inherit
      pkgs
      lib
      dk
      scriptsDir
      ;
    modelCallCfg = cfg.modelCall;
  };

  mkHooks = import ./hooks.nix {
    inherit
      pkgs
      lib
      dk
      scriptsDir
      nuModules
      promptFragments
      fileFormatter
      mkModelCall
      ;
    modelCatalog = resolvedModelCatalog;
    modelCallCfg = cfg.modelCall;
    timeouts = resolvedTimeouts;
    inherit (cfg) dataDir;
    inherit (config.xdg) dataHome;
  };

  notify = import ./notify.nix {
    inherit
      pkgs
      lib
      dk
      scriptsDir
      ;
    notifyCfg = cfg.notify;
  };

  prosePolishSkill = import ./prose-polish.nix {
    inherit
      pkgs
      lib
      dk
      assetsDir
      promptFragments
      ;
    modelCatalog = resolvedModelCatalog;
    modelCall = mkModelCall {
      assistant = "prose-polish";
      timeout = 300;
    };
  };

  normalizeSkillEntry =
    entry:
    if builtins.isAttrs entry && entry ? source then
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

  isUnderXdgData = lib.hasPrefix "${config.xdg.dataHome}/" cfg.instructions.docsDir;
  docsDirXdgRel = lib.removePrefix "${config.xdg.dataHome}/" cfg.instructions.docsDir;
  docsDirHomeRel = lib.removePrefix "${config.home.homeDirectory}/" cfg.instructions.docsDir;
in
{
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

      baseText = lib.mkOption {
        type = lib.types.lines;
        default = instructionAssets.renderBase (
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
    };

    roles = {
      definitions = lib.mkOption {
        type = lib.types.attrsOf roleSubmodule;
        default = { };
        description = "Shared agent role definitions available to assistant adapters";
      };

      defaultEnabled = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = builtins.attrNames cfg.roles.definitions;
        description = "Default list of enabled agent role names";
      };
    };

    permissions = {
      ownRepositories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Repository URL prefixes allowed for git push and pull operations";
      };

      allowCommands = {
        readOnly = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra read-only command patterns added to the allowlist";
        };

        mutating = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra mutating command patterns added to the allowlist";
        };
      };

      gateCommands = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "Extra command gate entries merged into the permissions policy";
      };

      mcpAllows = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = "Extra allowed MCP tools keyed by server name";
      };

      mcpGates = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf (lib.types.attrsOf lib.types.anything));
        default = { };
        description = "Extra gated MCP tools keyed by server name";
      };

      allowPolicies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra policy statements appended to the allowlist";
      };

      gatePolicies = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = "Extra policy entries appended to the gate list";
      };
    };

    models = {
      catalog = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
        default = { };
        description = "Model definitions recursively merged onto the built-in catalog";
      };

      defaults = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Per-family tier defaults and prose model merged onto the built-in defaults";
      };

      workloadPolicy = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        description = "Per-family effort levels per tier merged onto the built-in workload policy";
      };
    };

    providers = lib.mkOption {
      type = lib.types.attrsOf providerSubmodule;
      default = { };
      description = "Model providers referenced by authentication profiles";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileSubmodule;
      default = { };
      description = "Authentication and model-routing profiles shared across assistants";
    };

    modelCall = {
      enable = lib.mkEnableOption "OpenAI-compatible model call endpoint for LLM-backed hooks and skills";

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Base URL of the OpenAI-compatible chat completions endpoint";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path containing the default API key for model calls";
      };

      clientApiKeyFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Per-caller runtime API key file paths overriding apiKeyFile";
      };

      caCertFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime file path to a custom CA certificate bundle for model calls";
      };

      extraHeaders = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra HTTP headers included in model call requests";
      };

      commentGateModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override model ID used by the comment-gate hook";
      };

      timeouts = {
        modelConnect = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "TCP connection timeout in seconds for model calls";
        };

        modelCall = lib.mkOption {
          type = lib.types.int;
          default = 90;
          description = "Default request timeout in seconds for model calls";
        };

        modelHookMargin = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Extra seconds a hook outlives its model call so timeouts can be reported";
        };
      };
    };

    mcp = {
      timeouts = {
        startup = lib.mkOption {
          type = lib.types.int;
          default = 120;
          description = "Startup timeout in seconds for MCP servers";
        };
      };

      uv = {
        isolatedConfig = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Pass --no-config to uvx when launching Python MCP servers";
        };
      };

      disabledServers = agentsLib.mcp.mkDisabledServersOption {
        description = "Global MCP servers to disable across all assistants";
      };

      servers = lib.mkOption {
        type = lib.types.attrsOf mcpServerSubmodule;
        default = { };
        description = "Declared MCP servers wrapped and exposed to assistants";
      };

      presets = {
        github = {
          enable = lib.mkEnableOption "GitHub MCP server preset";

          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.mcp-server-github or selfPackages.mcp-server-github;
            description = "GitHub MCP server package";
          };

          ghPackage = lib.mkOption {
            type = lib.types.package;
            default = config.programs.gh.package or pkgs.gh;
            description = "GitHub CLI package used to read the active auth token";
          };

          fallbackTokenFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime file path to a fallback GitHub token used on HTTP 401";
          };
        };

        gitlab = {
          enable = lib.mkEnableOption "GitLab MCP server preset";

          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.mcp-server-gitlab or selfPackages.mcp-server-gitlab;
            description = "GitLab MCP server package";
          };

          glabPackage = lib.mkOption {
            type = lib.types.package;
            default = pkgs.glab;
            description = "GitLab CLI package used to read the active host and token";
          };

          fallbackTokenFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime file path to a fallback GitLab token when glab is not configured";
          };

          fallbackApiUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Fallback GitLab API v4 URL paired with fallbackTokenFile";
          };

          toolsets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "branches"
              "issues"
              "labels"
              "merge_requests"
              "pipelines"
              "projects"
              "repositories"
            ];
            description = "GitLab MCP toolsets enabled by default";
          };
        };

        exa = {
          enable = lib.mkEnableOption "Exa MCP server preset";

          apiKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime file path containing the Exa API key";
          };

          enabledTools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "web_search_exa"
              "web_fetch_exa"
              "web_search_advanced_exa"
              "agent_run"
            ];
            description = "Exa MCP tools enabled by default";
          };
        };

        chromeDevtools = {
          enable = lib.mkEnableOption "Chrome DevTools MCP server preset";

          headless = lib.mkOption {
            type = lib.types.bool;
            default = !pkgs.stdenv.isDarwin;
            description = "Launch Chromium in headless mode";
          };

          chromiumPackage = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = cfg.browser.chromiumPackage;
            description = "Chromium executable package passed to chrome-devtools-mcp";
          };
        };

        deepwiki = {
          enable = lib.mkEnableOption "DeepWiki HTTP MCP server preset";

          url = lib.mkOption {
            type = lib.types.str;
            default = "https://mcp.deepwiki.com/mcp";
            description = "DeepWiki MCP endpoint URL";
          };
        };

        scrapling = {
          enable = lib.mkEnableOption "Scrapling MCP server preset";

          chromiumPackage = lib.mkOption {
            type = lib.types.nullOr lib.types.package;
            default = cfg.browser.chromiumPackage;
            description = "Chromium executable package passed to scrapling-mcp";
          };
        };

        atlassian = {
          enable = lib.mkEnableOption "Atlassian MCP server preset";

          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Confluence base URL exported as CONFLUENCE_URL";
          };

          tokenFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Runtime file path containing the Confluence personal access token";
          };

          clearProxy = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Clear HTTP(S) proxy environment variables before launching mcp-atlassian";
          };
        };
      };
    };

    skills = {
      sources = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.either (lib.types.either lib.types.path lib.types.str) skillSourceSubmodule
        );
        default = { };
        description = "Skill directories installed into enabled assistant targets";
      };

      prosePolish = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = cfg.modelCall.enable;
          description = "Install the built-in prose-polish skill when modelCall is enabled";
        };
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
      };
    };

    hooks = {
      fileFormatterPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.file-formatter or selfPackages.file-formatter;
        description = "File formatter package invoked by post-edit formatting hooks";
      };

      timeouts = {
        tool = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Timeout in seconds for lightweight tool hooks";
        };

        postEdit = lib.mkOption {
          type = lib.types.int;
          default = 120;
          description = "Timeout in seconds for post-edit formatting hooks";
        };
      };
    };

    notify = {
      toastyPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = defaultToasty;
        description = "Package providing toasty.exe for WSL toast notifications";
      };

      libnotifyPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = if pkgs.stdenv.isLinux then pkgs.libnotify else null;
        description = "Package providing notify-send for Linux desktop notifications";
      };
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
  config = lib.mkMerge [
    {
      agents = {
        instructions = {
          docs = lib.mapAttrs (_: lib.mkDefault) instructionAssets.defaultDocs;
          extraLinks."@devkitSource@" = lib.mkDefault devkitOutPath;
        };

        roles.definitions = lib.mapAttrs (
          _: role: lib.mapAttrs (_: lib.mkDefault) role
        ) roleAssets.definitions;

        mcp.servers = mcpResult.presetServers;

        skills.sources = lib.mkIf (cfg.skills.prosePolish.enable && cfg.modelCall.enable) {
          prose-polish = lib.mkDefault {
            source = prosePolishSkill;
            trustedScripts = prosePolishSkill.scripts;
          };
        };

        resolved = {
          inherit
            agentRoleOptions
            agentRoles
            anthropicProfiles
            configDirs
            fileFormatter
            mkHooks
            mkModelCall
            mkProfileSwitch
            mkSkillScriptPaths
            notify
            profileResolver
            promptFragments
            resolveProfiles
            ;

          inherit (cfg) dataDir;
          instructions = resolvedInstructions;
          instructionsDir = cfg.instructions.docsDir;
          instructionDocs = cfg.instructions.docs;

          preferences = {
            askTimeout = 300;
            plansDir = ".agents/plans";
          };

          modelCatalog = resolvedModelCatalog;
          workloadPolicy = resolvedWorkloadPolicy;
          permissions = resolvedPermissions;
          timeouts = resolvedTimeouts;

          mcp = {
            servers = mcpResult.resolvedServers;
            serverNames = builtins.attrNames mcpResult.resolvedServers;
            inherit (mcpResult) displayNames;
            inherit (cfg.mcp) timeouts disabledServers;
            inherit (agentsLib.mcp) computeEnabledServers mkMcpOptions;
          };
        };
      };

      assertions = [
        {
          assertion = cfg.modelCall.enable -> cfg.modelCall.baseUrl != null;
          message = "agents.modelCall.baseUrl must be set when agents.modelCall.enable is true";
        }
      ]
      ++ lib.mapAttrsToList (name: server: {
        assertion =
          server.enable -> (if server.type == "http" then server.url != null else server.command != [ ]);
        message =
          if server.type == "http" then
            "agents.mcp.servers.${name}.url must be set for HTTP MCP servers"
          else
            "agents.mcp.servers.${name}.command must be non-empty for stdio MCP servers";
      }) cfg.mcp.servers;
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

    (lib.mkIf cfg.skills.targets.claude {
      home.file = mkSkillFiles {
        directory = "${configDirs.claude}/skills";
        recursive = true;
      };
    })

    (lib.mkIf cfg.skills.targets.omp {
      home.file = mkSkillFiles {
        directory = "${configDirs.omp}/skills";
        recursive = true;
      };
    })

    (lib.mkIf cfg.skills.targets.codex {
      home.file = mkSkillFiles {
        directory = "${configDirs.codex}/skills";
        recursive = false;
      };
    })
  ];
}
