# ==================================================================================================
# Home Manager Modules
# ==================================================================================================

{
  self,
  nixpkgs-unstable,
  devkit,
  llm-agents,
  activity-report,
  agent-project-move,
  claude-statusline,
  oxide-code,
  agentsLib,
}:

let
  mkHomeModule = name: module: {
    _class = "homeManager";
    _file = "${self}/flake.nix#homeModules.${name}";
    key = "${self}/flake.nix#homeModules.${name}";
    imports = [ module ];
  };

  sharedModule = mkHomeModule "shared" (
    import ./shared {
      inherit self devkit agentsLib;
    }
  );

  individualHomeModules = {
    shared = sharedModule;

    claude-code = mkHomeModule "claude-code" (
      import ./claude-code {
        inherit
          llm-agents
          claude-statusline
          agentsLib
          sharedModule
          ;
      }
    );

    codex = mkHomeModule "codex" (
      import ./codex {
        inherit
          devkit
          llm-agents
          agentsLib
          sharedModule
          ;
      }
    );

    omp = mkHomeModule "omp" (
      import ./omp {
        inherit llm-agents agentsLib sharedModule;
      }
    );

    oxide-code = mkHomeModule "oxide-code" (
      import ./oxide-code {
        inherit oxide-code agentsLib sharedModule;
      }
    );

    acp = mkHomeModule "acp" (
      import ./acp {
        inherit
          self
          llm-agents
          agentsLib
          sharedModule
          ;
      }
    );

    activity-report = mkHomeModule "activity-report" (
      import ./activity-report {
        inherit activity-report sharedModule;
      }
    );

    agent-project-move = mkHomeModule "agent-project-move" (
      import ./agent-project-move {
        inherit agent-project-move sharedModule;
      }
    );

    ccusage = mkHomeModule "ccusage" (
      import ./ccusage {
        inherit llm-agents sharedModule;
      }
    );

    ctx7 = mkHomeModule "ctx7" (
      import ./ctx7 {
        inherit nixpkgs-unstable agentsLib sharedModule;
      }
    );

    t3code = mkHomeModule "t3code" (
      import ./t3code {
        inherit
          nixpkgs-unstable
          devkit
          agentsLib
          sharedModule
          ;
      }
    );

    workmux = mkHomeModule "workmux" (
      import ./workmux {
        inherit llm-agents sharedModule;
      }
    );
  };
in
individualHomeModules
// {
  default = mkHomeModule "default" {
    imports = builtins.attrValues individualHomeModules;
  };
}
