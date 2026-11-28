# AGENTS.md: agents.nix

## Read before you edit

| When the change touches | Read                                                                      |
| ----------------------- | ------------------------------------------------------------------------- |
| CI or a workflow        | [devkit's CI guide](https://github.com/hakulab/devkit/blob/v3/docs/ci.md) |
| A manual dependency pin | [Pinned Versions](.agents/skills/pinned-versions/SKILL.md)                |
| A release               | [RELEASING.md](RELEASING.md)                                              |

## Rules for every change

- Run the pre-commit hooks on every commit. In each new checkout or worktree, run `nix develop -c true` once to install them and link `/.pre-commit-config.yaml`. Never bypass the hooks with `--no-verify` or `PREK_ALLOW_NO_CONFIG`.
- Wrap code and comments at 100 columns, counting the indent, end section banners at column 100, and keep a single-line string literal whole at any length.
- Use Nushell as the default for helper scripts. Reserve POSIX shell or Bash for scripts evaluated or sourced by another shell and for thin `exec` wrappers.
- Keep `devkit`'s `nixpkgs-unstable` input independent of `nixpkgs` so `devkit.lib.mkLib` can select newer Nushell when needed.
- Keep all modules, assets, and scripts free of private or corporate details, hardcoded secret backends, and host-specific policy. Accept secrets through backend-agnostic `*File` paths read at runtime.
- Link only public material in documentation, issues, pull requests, and comments. Never reference local working notes, private paths, or private repositories.

## Verification

```bash
nix flake check --all-systems
nix develop -c run-hooks
```
