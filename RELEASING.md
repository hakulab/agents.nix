# Releasing

Use the [release skill](https://github.com/hakulab/plugins/blob/main/plugins/hakula-workflow/skills/release/SKILL.md) with the versioning contract below.

## Versioning

- **Before 1.0**: tag `v0.N.0` whenever a user-visible batch lands, and `v0.N.M` for a fix to shipped behavior. A breaking change to the stability surface bumps the minor version and is listed under Breaking changes.
- **After 1.0**: a breaking change to the [stability surface](#stability-surface) bumps the major version, a user-visible addition or change bumps the minor version, and a fix bumps the patch version.

### Stability surface

Within a minor version, stable releases keep exported flake outputs and documented module interfaces compatible. Currently exported outputs:

- `lib`
- `homeModules.shared`
- `overlays.default`
- `packages.<system>`
- `checks.<system>`
- `devShells.<system>.default`
- `formatter.<system>`

Expand this list as Home Manager, NixOS, and nix-darwin modules are added.

## Preparation and verification

Draft release notes with devkit's shared changelog generator, update `CHANGELOG.md`, and run the [verification commands](AGENTS.md#verification). Mark changes to the stability surface with `!` in the conventional commit title.

```bash
nix run github:hakulab/devkit/v3#changelog -- vX.Y.Z
```
