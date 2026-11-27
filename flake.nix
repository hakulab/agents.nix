# ==================================================================================================
# agents.nix
# ==================================================================================================

{
  description = "Declarative Nix and Home Manager modules for coding agents, MCP servers, hooks, and skills";

  nixConfig = {
    extra-substituters = [ "https://hakula.cachix.org" ];
    extra-trusted-public-keys = [
      "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k="
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # Inputs
  # ------------------------------------------------------------------------------------------------
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    devkit = {
      url = "github:hakulab/devkit/v3";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
      };
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    activity-report = {
      url = "github:hakulab/activity-report";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        devkit.follows = "devkit";
      };
    };

    agent-project-move = {
      url = "github:hakulab/agent-project-move";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        devkit.follows = "devkit";
      };
    };

    claude-statusline = {
      url = "github:hakulab/claude-statusline";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        devkit.follows = "devkit";
      };
    };

    oxide-code = {
      url = "github:hakulab/oxide-code";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        devkit.follows = "devkit";
        home-manager.follows = "home-manager";
      };
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Outputs
  # ------------------------------------------------------------------------------------------------
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      devkit,
      home-manager,
      llm-agents,
      activity-report,
      agent-project-move,
      claude-statusline,
      oxide-code,
    }:
    let
      agentsLib = import ./lib {
        inherit (nixpkgs) lib;
      };

      packagesFor = system: self.packages.${system};
      unstablePackagesFor = system: nixpkgs-unstable.legacyPackages.${system};
      llmAgentsPackagesFor = system: llm-agents.packages.${system};

      # Pull Playwright from nixpkgs-unstable because Chrome DevTools MCP tracks latest npm and
      # requires current stable Chrome, while stable nixpkgs freezes Chromium.
      playwrightDriverFor = system: (unstablePackagesFor system).playwright-driver;

      mkHomeModule = name: module: {
        _class = "homeManager";
        _file = "${self}/flake.nix#homeModules.${name}";
        key = "${self}/flake.nix#homeModules.${name}";
        imports = [ module ];
      };

      sharedHomeModule = mkHomeModule "shared" (
        import ./modules/home/shared {
          inherit agentsLib;
          devkitLib = devkit.lib;
          devkitOutPath = devkit.outPath;
          repoRoot = ./.;
          inherit packagesFor;
        }
      );

      claudeCodeHomeModule = mkHomeModule "claude-code" (
        import ./modules/home/claude-code {
          inherit agentsLib;
          claudeStatuslineFor = system: claude-statusline.packages.${system};
          claudeStatuslineModule = claude-statusline.homeModules.default;
          llmAgentsFor = system: llm-agents.packages.${system};
          repoRoot = ./.;
          inherit sharedHomeModule;
        }
      );

      codexHomeModule = mkHomeModule "codex" (
        import ./modules/home/codex {
          inherit agentsLib;
          devkitLib = devkit.lib;
          llmAgents = llm-agents;
          repoRoot = ./.;
          inherit sharedHomeModule;
        }
      );

      ompHomeModule = mkHomeModule "omp" (
        import ./modules/home/omp {
          inherit agentsLib sharedHomeModule;
          llmAgentsPackagesFor = system: llm-agents.packages.${system};
          repoRoot = ./.;
        }
      );

      oxideCodeHomeModule = mkHomeModule "oxide-code" (
        import ./modules/home/oxide-code {
          inherit agentsLib sharedHomeModule;
          oxideCodeHomeModule = oxide-code.homeModules.default;
          oxideCodePackagesFor = system: oxide-code.packages.${system};
          repoRoot = ./.;
        }
      );

      individualHomeModules = {
        acp = mkHomeModule "acp" (
          import ./modules/home/acp {
            inherit agentsLib;
            sharedModule = sharedHomeModule;
            inherit packagesFor llmAgentsPackagesFor;
          }
        );

        activity-report = mkHomeModule "activity-report" (
          import ./modules/home/activity-report {
            sharedModule = sharedHomeModule;
            activityReportModule = activity-report.homeModules.default;
            activityReportPackagesFor = system: activity-report.packages.${system};
          }
        );

        agent-project-move = mkHomeModule "agent-project-move" (
          import ./modules/home/agent-project-move {
            sharedModule = sharedHomeModule;
            agentProjectMoveModule = agent-project-move.homeModules.default;
            agentProjectMovePackagesFor = system: agent-project-move.packages.${system};
          }
        );

        ccusage = mkHomeModule "ccusage" (
          import ./modules/home/ccusage {
            sharedModule = sharedHomeModule;
            inherit llmAgentsPackagesFor;
          }
        );

        claude-code = claudeCodeHomeModule;
        codex = codexHomeModule;

        ctx7 = mkHomeModule "ctx7" (
          import ./modules/home/ctx7 {
            inherit agentsLib;
            sharedModule = sharedHomeModule;
            inherit unstablePackagesFor;
          }
        );

        omp = ompHomeModule;
        oxide-code = oxideCodeHomeModule;
        shared = sharedHomeModule;

        t3code = mkHomeModule "t3code" (
          import ./modules/home/t3code {
            inherit agentsLib;
            devkitLib = devkit.lib;
            repoRoot = ./.;
            sharedModule = sharedHomeModule;
            inherit unstablePackagesFor;
          }
        );

        workmux = mkHomeModule "workmux" (
          import ./modules/home/workmux {
            sharedModule = sharedHomeModule;
            inherit llmAgentsPackagesFor;
          }
        );
      };

      homeModules = individualHomeModules // {
        default = mkHomeModule "default" {
          imports = [
            individualHomeModules.acp
            individualHomeModules.activity-report
            individualHomeModules.agent-project-move
            individualHomeModules.ccusage
            individualHomeModules.claude-code
            individualHomeModules.codex
            individualHomeModules.ctx7
            individualHomeModules.omp
            individualHomeModules.oxide-code
            individualHomeModules.shared
            individualHomeModules.t3code
            individualHomeModules.workmux
          ];
        };
      };
    in
    {
      lib = agentsLib;

      inherit homeModules;

      overlays.default =
        final: _:
        import ./packages {
          pkgs = final;
          dk = devkit.lib.mkLib final;
          playwrightDriver = playwrightDriverFor final.stdenv.hostPlatform.system;
        };
    }
    // devkit.lib.eachSystem devkit.lib.systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        dk = devkit.lib.mkLib pkgs;
        nuLibDirs = [
          ./scripts/lib
          ./tests/lib
        ];

        preCommit = dk.preCommit {
          src = ./.;
          hooks = {
            doctoc.enable = true;
            lychee = {
              enable = true;
              settings.flags = "--offline --exclude '@(docsDir|devkitSource)@'";
            };
            nu-check = {
              enable = true;
              settings.libDirs = nuLibDirs;
            };
            prettier.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            taplo.enable = true;
          };
        };

        packages = import ./packages {
          inherit pkgs dk;
          playwrightDriver = playwrightDriverFor system;
        };

        libChecks = import ./tests/lib-checks {
          inherit pkgs;
          inherit (nixpkgs) lib;
          inherit agentsLib;
        };

        homeChecks = import ./tests/home-checks {
          inherit pkgs;
          inherit (nixpkgs) lib;
          inherit home-manager homeModules;
          darwinPkgs = nixpkgs.legacyPackages.aarch64-darwin;
          sharedModule = sharedHomeModule;
          claudeCodeModule = claudeCodeHomeModule;
          codexModule = codexHomeModule;
          ompModule = ompHomeModule;
          oxideCodeModule = oxideCodeHomeModule;
        };

        nuTests = dk.nuTests {
          src = ./.;
          runtimeInputs = [
            pkgs.direnv
            pkgs.git
            pkgs.nixfmt
            pkgs.prek
          ];
          libDirs = nuLibDirs;
        };

        tsTests =
          pkgs.runCommand "ts-tests"
            {
              nativeBuildInputs = [ pkgs.bun ];
            }
            ''
              bun test ${./scripts/omp}/file-formatter.test.ts
              touch "$out"
            '';
      in
      {
        # ------------------------------------------------------------------------------------------
        # Dev shell
        # ------------------------------------------------------------------------------------------
        devShells.default = pkgs.mkShell {
          name = "agents-nix-dev";
          packages = [
            dk.nushell
            dk.nu-test
            pkgs.bun
          ];
          inputsFrom = [
            preCommit
          ];
          shellHook = ''
            repo_root="$(git rev-parse --show-toplevel)"
            export NU_LIB_DIRS="$repo_root/scripts/lib:$repo_root/tests/lib"
          '';
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        inherit packages;

        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks =
          self.packages.${system}
          // libChecks
          // homeChecks
          // {
            nu-tests = nuTests;
            ts-tests = tsTests;
          };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
