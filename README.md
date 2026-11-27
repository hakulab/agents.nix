# agents.nix

[![CI](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml/badge.svg)](https://github.com/hakulab/agents.nix/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Declarative Nix and Home Manager configuration for coding agents (Claude Code, Codex, OMP, Oxide Code, MCP servers, hooks, skills, and companion tools) across Linux (`x86_64-linux`, `aarch64-linux`) and macOS (`aarch64-darwin`).

## Flake outputs

- `homeModules`: Home Manager modules under the `agents.*` option namespace.
- `nixosModules` and `darwinModules`: system-level integration modules.
- `lib`: pure Nix helpers for models, profiles, permissions, MCP servers, prompts, proxies, and wrappers.
- `packages.<system>` and `overlays.default`: companion packages and overlay.
- `devShells.<system>.default`, `checks.<system>`, and `formatter.<system>`: development environment, automated checks, and `nixfmt-tree`.

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
