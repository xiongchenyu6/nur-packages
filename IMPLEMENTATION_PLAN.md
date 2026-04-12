## Stage 1: Refresh nixpkgs lock
**Goal**: Move the pinned nixpkgs revision to one that provides Go 1.26.2 or newer.
**Success Criteria**: `flake.lock` updates successfully and evaluation can see a newer Go toolchain.
**Tests**: Evaluate or build `sub2api` against the updated lock.
**Status**: Complete

## Stage 2: Rebuild sub2api
**Goal**: Verify `sub2api` builds with the refreshed Go toolchain.
**Success Criteria**: `nix build .#sub2api` succeeds, or fails only with an expected fixed-output hash mismatch.
**Tests**: `nix build .#sub2api`
**Status**: Complete

## Stage 3: Refresh package hash if needed
**Goal**: Update `pkgs/sub2api/package.nix` only if the nixpkgs bump changes vendoring output.
**Success Criteria**: Correct `vendorHash` is recorded and the build succeeds.
**Tests**: `nix build .#sub2api`
**Status**: Complete

## Stage 4: Final verification
**Goal**: Confirm the package builds cleanly with minimal changes.
**Success Criteria**: `sub2api` builds successfully and no extra package-specific Go override was introduced.
**Tests**: `nix build .#sub2api`
**Status**: Complete
