# Publishing Irilon via Vellum

Vellum (https://github.com/vellum-dev/vellum) is an `apk`-based package manager
for reMarkable. Distribution is done by adding a package recipe to the curated
`vellum-dev/vellum` repository; their CI builds/signs it and it appears in the
package index at https://vellum.delivery.

This folder holds the recipe (`irilon/VELBUILD`) so it lives under version
control with the app and can be updated in step with each release.

## One-time prerequisites

- Install Vellum on a device and confirm `appload` installs/runs from the
  index (Irilon is an AppLoad application and depends on it).
- Have a GitHub account and join the Vellum community (Discord:
  https://discord.gg/u3P9sDW) for review/coordination.

## Release process

1. **Tag & attach** in the app repo: tag `vX.Y.Z` on `drafts`, run
   `./build.sh 4` (version is derived from the git tag), attach the two zips
   (`irilon-X.Y.Z-arm64.zip`, `irilon-X.Y.Z-armv7.zip`) to the GitHub release.
   Release assets must be immutable - never re-upload an existing asset.
2. **Bump the recipe** in `irilon/VELBUILD`: `pkgver` (semver, no leading "v"),
   reset `pkgrel` to 0, update URLs if they embed the version.
3. **Checksums** (run from a `vellum-dev/vellum` checkout after copying the
   recipe to `packages/irilon/`):
   `./scripts/update-checksums.sh irilon`
4. **Lint & build locally**:
   `./scripts/lint-packages.sh irilon --apkbuild-lint`
   `./scripts/build-package.sh irilon aarch64` (and `armv7`)
5. **PR** to `vellum-dev/vellum` with `packages/irilon/VELBUILD`.
   Important: Vellum closes PRs that appear agent/LLM-authored, so open it
   yourself with your own identity.
6. **Test on device** through their testing repo:
   `vellum testing enable && vellum update && vellum add irilon@testing`
   Validate on each device/OS you claim support for, then comment
   `/ready-for-review` on the PR.
7. Maintainers publish to the main index; users install with `vellum add irilon`.

## Compatibility declarations

The recipe declares support for reMarkable 2, Paper Pro, Paper Pro Move and
Paper Pro Pure by excluding only the reMarkable 1 (`depends="appload !rm1"`).
If device coverage changes, update the exclusion list (and validate on-device
via the testing repo before broadening the claim).
