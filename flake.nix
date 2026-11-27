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

      # Pull Playwright from nixpkgs-unstable because Chrome DevTools MCP tracks latest npm and
      # requires current stable Chrome, while stable nixpkgs freezes Chromium.
      playwrightDriverFor = system: nixpkgs-unstable.legacyPackages.${system}.playwright-driver;

      homeModules = import ./modules/home {
        inherit
          self
          nixpkgs-unstable
          devkit
          llm-agents
          activity-report
          agent-project-move
          claude-statusline
          oxide-code
          agentsLib
          ;
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
          packages
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
