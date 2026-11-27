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
    }:
    let
      agentsLib = import ./lib {
        inherit (nixpkgs) lib;
      };

      # Pull Playwright from nixpkgs-unstable because Chrome DevTools MCP tracks latest npm and
      # requires current stable Chrome, while stable nixpkgs freezes Chromium.
      playwrightDriverFor = system: nixpkgs-unstable.legacyPackages.${system}.playwright-driver;
    in
    {
      lib = agentsLib;

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
        nuLibDirs = [ ./tests/lib ];

        preCommit = dk.preCommit {
          src = ./.;
          hooks = {
            doctoc.enable = true;
            lychee = {
              enable = true;
              settings.flags = "--offline";
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
          ];
          inputsFrom = [
            preCommit
          ];
          shellHook = ''
            export NU_LIB_DIRS="$(git rev-parse --show-toplevel)/tests/lib"
          '';
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        inherit packages;

        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks = self.packages.${system} // libChecks // { nu-tests = nuTests; };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
