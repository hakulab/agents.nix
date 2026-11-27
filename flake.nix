# ==================================================================================================
# agents.nix
# ==================================================================================================

{
  description = "Declarative Nix & Home Manager configuration for coding agents";

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

    devkit = {
      url = "github:hakulab/devkit/v3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Outputs
  # ------------------------------------------------------------------------------------------------
  outputs =
    {
      nixpkgs,
      devkit,
      ...
    }:
    {
      homeModules = { };
      nixosModules = { };
      darwinModules = { };
      lib = { };
      overlays.default = _: _: { };
    }
    // devkit.lib.eachSystem devkit.lib.systems (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        dk = devkit.lib.mkLib pkgs;

        preCommit = dk.preCommit {
          src = ./.;
          hooks = {
            doctoc.enable = true;
            lychee = {
              enable = true;
              settings.flags = "--offline";
            };
            nu-check.enable = true;
            prettier.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
            taplo.enable = true;
          };
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
        };

        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        packages = { };

        # ------------------------------------------------------------------------------------------
        # Checks
        # ------------------------------------------------------------------------------------------
        checks = { };

        # ------------------------------------------------------------------------------------------
        # Formatter
        # ------------------------------------------------------------------------------------------
        formatter = pkgs.nixfmt-tree;
      }
    );
}
