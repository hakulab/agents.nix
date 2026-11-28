---
name: pinned-versions
description: >-
  Audit and update the package, extension, and notification helper versions pinned in agents.nix.
  Use for dependency sweeps and hash mismatches after a version bump.
---

# Pinned Versions

Run the Nushell checker from the repository root. Online comparisons use GitHub CLI.

```bash
.agents/skills/pinned-versions/scripts/check-pins.nu
```

The default command and `check` compare the pins with their upstream versions. Use `list` for an offline inventory. A complete check exits `0` when every pin matches or `1` when any pin is `STALE`. An incomplete check exits `2`, even if it also finds stale pins. Resolve any `UNKNOWN` results before reporting a clean audit.

## Update a pin

For an audit, report the differences. When updating, change the source definition that owns each pin. Downstream flakes pick up the changes by updating their agents.nix input. Renovate manages flake inputs and GitHub Actions separately.

- **acpx and GitLab MCP** follow stable releases. Update the version and source hash first, then verify `pnpmDeps.hash` for acpx or `npmDepsHash` for GitLab MCP. Rebuild the fixed-output dependency derivation with `nix build --rebuild` to verify its hash even when the store already contains it.
- **GitHub MCP** follows stable releases and fetches a separate archive for each supported platform. Hash the downloaded archive bytes for every entry in `sources`, including platforms unavailable on the build host.
- **OMP Telegram** publishes Git tags. Resolve the highest stable version tag to its full commit SHA, then update the extension's `rev`, tag comment, and source hash together.
- **Toasty** tracks the latest stable release that includes `toasty-x64.exe`. Update the URL and hash of that asset in the notification module.

Build each changed package and exercise its installed binary with a supported version or help command. For an extension or helper, build its fetch and check the consumer on a supported platform when available. Report any runtime check that still needs that platform.
