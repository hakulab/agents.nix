# agents.nix

[![CI](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml/badge.svg)](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![wakatime](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/ea3cd142-c1be-4e0d-8445-aaa205befa77.svg)](https://wakatime.com/badge/user/f4a35a1f-0e29-4093-a647-e66aad164737/project/ea3cd142-c1be-4e0d-8445-aaa205befa77)

Declarative Nix and Home Manager modules for coding agents, MCP servers, hooks, and skills across Linux (`x86_64-linux`, `aarch64-linux`) and macOS (`aarch64-darwin`).

## Flake outputs

- `lib`: pure Nix helpers for models, profiles, permissions, MCP servers, prompts, proxies, and package wrappers.
- `overlays.default`: overlay exposing the companion packages.
- `packages.<system>`: companion packages (`acpx`, `browser-tools`, `file-formatter`, `mcp-server-github`, `mcp-server-gitlab`).
- `checks.<system>`: library evaluation checks, Nushell script tests, and package builds.
- `devShells.<system>.default`: development shell with Nushell, `nu-test`, and pre-commit hooks.
- `formatter.<system>`: `nixfmt-tree` formatter.

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

```bash
nix develop
run-hooks
nix flake check --all-systems
```

See devkit's shared [CI](https://github.com/hakulab/devkit/blob/v3/docs/ci.md) and [release procedures](https://github.com/hakulab/devkit/blob/v3/docs/releasing.md).

## License

Copyright (c) 2026 [Hakula](https://hakula.xyz). Licensed under the [MIT License](LICENSE).
