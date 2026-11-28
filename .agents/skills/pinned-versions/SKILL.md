---
name: pinned-versions
description: >-
  Audit or upgrade manually pinned dependencies in agents.nix, including extension revisions,
  custom packages, and notification helpers. Use for stale dependency sweeps or hash mismatches
  after version bumps.
---

# Pinned Versions

Locate pins through `scripts/check-pins.nu`, compare upstream versions, and update the relevant source and hashes. Run commands from the repository root. An audit reports drift. When upgrading, keep unrelated pins and lockfile inputs outside the change. Skip a pin that another open request owns, and name that request in the upgrade request's description.

## Check for drift

```bash
.agents/skills/pinned-versions/scripts/check-pins.nu
```

`list` prints the registry without network calls and needs Nushell and Git. The default command and `check` also need `gh` authenticated to `github.com`. A `STALE` value differs from the upstream target. An `UNKNOWN` means a lookup failed. Rerun the check and investigate any persistent failure. A complete check exits `0` when all pins match or `1` when any pin is stale. An incomplete check exits `2`, including when it also finds stale pins.

The registry can lag the repository. For a repository-wide audit, also inspect new packages, module defaults, flake inputs, and workflow references.

## Locked inputs and release selectors

Renovate manages `flake.lock` inputs, including rolling inputs such as `llm-agents`. To update an input to a different release series, change its selector in `flake.nix` and run `nix flake update <input>`. Review the nixpkgs and Home Manager stable branches together for a release upgrade. Downstream flakes pick up changes to the packages and modules here by updating their agents.nix input.

## Nix-built packages and fetched helpers

### Overlay packages

Update the package's `version` and source hash to the selected stable release. Check the upstream release notes for changes to the commands and options the consuming module uses.

- `acpx` needs `pnpmDeps.hash`.
- `mcp-server-gitlab` needs `npmDepsHash`.
- `mcp-server-github` fetches release archives with `fetchurl`. Prefetch their bytes without `--unpack` and update every platform entry, including those unavailable locally.

Use `lib.fakeHash` temporarily to obtain the expected hash from a Nix mismatch error. Resolve the source hash first, then rebuild the fixed-output dependency derivation with `nix build --rebuild` to confirm its hash. Nix keeps a mismatched fetch under its real hash, which a later build can reuse. Remove all placeholders before committing.

These packages are also flake outputs. Build the changed package directly, then run a supported version or help command from its store path to check the wrapper and entry point.

```bash
nix build --no-link --print-out-paths .#acpx
```

### OMP extensions

`omp-telegram` publishes version tags without GitHub release objects. Resolve the highest stable version tag to its full commit SHA. Update the `rev`, tag comment, and source hash together. Build a Home Manager configuration with the extension enabled to verify the installed source.

### Windows notification helper

`toasty` tracks the latest stable release that includes `toasty-x64.exe`. Update the release tag in the URL and the `fetchurl` hash together, then build an `x86_64-linux` configuration with assistant notifications enabled to validate the fetch and wrapper. Runtime notification verification requires Windows interoperability in WSL.

## Runtime packages

### Unpinned MCP wrappers

The `npx` and `uvx` presets that select the latest package at runtime stay outside the checker.

## GitHub Actions

Renovate manages workflow references. Review breaking changes to referenced actions and reusable workflows, and check an actual CI run when a major tag moves. See the [GitHub Actions workflow](../../../.github/workflows/ci.yml) for triggers.

## Verification

Follow [repository verification](../../../AGENTS.md#verification) for formatting and builds. Verify each changed fetch, then build the package or Home Manager configuration that consumes it. A successful fetch for another platform establishes that its asset matches the recorded hash. Runtime checks require a compatible platform.

Report which pins changed, the upstream releases or commits selected, and the checks actually completed. Identify incomplete upstream queries and any runtime checks still outstanding.
