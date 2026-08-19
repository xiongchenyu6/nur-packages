# DeepSeek Harness (`deepseek-harness`)

This package wraps `@deepseek-ai/dsh` (`dsh`) for Nix.

## What this package does

- Installs `@deepseek-ai/dsh` version `0.1.0-rc.7` from npm tarball.
- Applies the CLI requirement for the built-in HMR plugin:
  `--expose-internals`.
- Keeps the binary executable and exposes `dsh` as `mainProgram`.

## Why this exists

`dsh web` crashes inside `cordis-plugin-hmr` without `--expose-internals`.
The package fixes this by rewriting the generated launcher script in `postInstall`.

## Files

- `package.nix` — Nix derivation.
- `package-lock.json` — vendored lockfile used by `npmConfigHook` for reproducibility.

## Build

From repo root:

```sh
nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in (pkgs.callPackage ./pkgs/deepseek-harness/package.nix {})'
```

If the package is added to `flake.nix` exports:

```sh
nix build .#deepseek-harness
```

## Smoke checks

```sh
./result/bin/dsh --version
# expect: 0.1.0-rc.7

# quick web smoke test (start + timeout)
timeout 12s ./result/bin/dsh web
# expect: dsh web: http://127.0.0.1:3080
```

Inspect launcher command line:

```sh
grep -n '^exec ' ./result/bin/dsh
```

You should see `--expose-internals`.

## Packaging notes for Codex maintainers

### Keep the `postInstall` implementation

`dsh` entrypoint is generated as a small shell wrapper in `$out/bin/dsh`.
The implementation intentionally avoids `sed -i` in-place edits, because
that path can trigger a build-time segfault in this environment.

Current safe pattern (already in `package.nix`):

1. Read original shebang line.
2. Parse the original `exec` node path and arguments.
3. Rewrite `bin/dsh` atomically via heredoc.
4. Reapply executable bit.

### Version bump checklist

When updating `@deepseek-ai/dsh`:

1. Update `version` in `package.nix`.
2. Update `src.url` hash (tgz hash).
3. Recompute and set `npmDepsHash`.
4. If applicable, adjust `changelog` URL.

## Related issue fixed

- Initial runs failed with:
  `Error: failed to apply loader entry ... --expose-internals is required for HMR service`
- Current build verifies by running `--version` and timed `dsh web` smoke test.
