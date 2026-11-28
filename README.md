# agents.nix

[![CI](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml/badge.svg)](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![WakaTime coding time for agents.nix](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/ea3cd142-c1be-4e0d-8445-aaa205befa77.svg)

Declarative Nix and Home Manager modules for coding agents, MCP servers, hooks, and skills on Linux (`x86_64-linux`, `aarch64-linux`) and macOS (`aarch64-darwin`).

## Quickstart

Add `agents-nix` to your flake inputs, import `agents-nix.homeModules.default` (or an individual module from `homeModules`), and enable the clients you use. Every assistant and peripheral tool is disabled by default, and every individual module imports `homeModules.shared` with deduplication.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agents-nix = {
      url = "github:hakulab/agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      agents-nix,
      ...
    }:
    {
      homeConfigurations.dev = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          agents-nix.homeModules.default
          {
            home = {
              username = "dev";
              homeDirectory = "/home/dev";
              stateVersion = "26.05";
            };

            agents.claude-code.enable = true;
          }
        ];
      };
    };
}
```

To use Antigravity CLI with a Google AI subscription, set `agents.agy.enable = true`. After activation, run `agy` and sign in with the Google account for that subscription. The CLI starts with the default model and reasoning effort from the shared Gemini policy. To override the default for one session, run `agy --model <slug>`.

Custom agents request the native Flash or Pro tier when their shared workload uses a distinct mini or flagship model. Google selects the model and effort for those tiers. Otherwise custom agents inherit the active session model and effort.

With `agents.acp.enable` and `agents.agy.enable`, `acpx` can launch `agy acp`. To register the same server independently, enable `agents.acp.agyAdapter.enable` in your ACP configuration.

Supply each secret as a runtime file path string, such as `"/run/secrets/api-key"`. Literal environment values and HTTP headers in your Nix configuration are written to the Nix store.

For clients that support authentication profiles, use `config.agents.resolved.clientProfiles.<client>` to select a default profile. The read-only map applies the client's allowlists and API restrictions before generating client-specific files.

See [`flake.nix`](flake.nix) for exported outputs, [`modules/home/`](modules/home/) for available modules and option definitions, and [`packages/`](packages/) for companion packages. Prompts, instructions, skills, and helper scripts live as plain files under [`assets/`](assets/) and [`scripts/`](scripts/) for browsing or adapting outside Nix, while the Nix modules expand `@placeholder@` tokens and wrap scripts at build time.

## Cache

Input flakes' `nixConfig` is not inherited. Configure the binary cache in your root flake:

```nix
nixConfig = {
  extra-substituters = [ "https://hakula.cachix.org" ];
  extra-trusted-public-keys = [
    "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k="
  ];
};
```

For NixOS or nix-darwin, place the same settings under `nix.settings` according to your host's trust policy.

## Development

See [`AGENTS.md`](AGENTS.md) for contributor rules and verification commands, and [`RELEASING.md`](RELEASING.md) for the release contract.

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
