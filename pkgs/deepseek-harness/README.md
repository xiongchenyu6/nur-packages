# DeepSeek Harness (`deepseek-harness`)

This package wraps `@deepseek-ai/dsh` (`dsh`) for Nix.

## 30-second quick start

```sh
# 1) Build package (local expression, works even before flake wiring)
nix build --impure --expr 'let pkgs = import <nixpkgs> {}; in (pkgs.callPackage ./pkgs/deepseek-harness/package.nix {})'

# 2) Confirm entry works
./result/bin/dsh --version

# 3) Run web alias once (expect local URL line)
timeout 12s ./result/bin/dsh web

# 4) Inspect launcher
grep -n '^exec ' ./result/bin/dsh

# 5) Open quick diagnostics if it fails
./result/bin/dsh --help
```

## What this package does

- Installs `@deepseek-ai/dsh` version `0.1.0-rc.7` from npm tarball.
- Applies the CLI requirement for the built-in HMR plugin:
  `--expose-internals`.
- Keeps the binary executable and exposes `dsh` as `mainProgram`.

## Why this exists

`dsh web` crashes inside `cordis-plugin-hmr` without `--expose-internals`.
The package fixes this by rewriting the generated launcher script in `postInstall`.

## How this differs from `codex` / `claude` / `opencode` / `pi`

Quick mental model: this is **not** a drop-in replacement for those tools.

| Tool family | Primary runtime | Target | Start/config style | Plugin/model layer |
|---|---|---|---|---|
| `dsh` / this package | `node` | DeepSeek harness profile/app launcher | `dsh` profile/subcommand model (`--profile`, `plugin`, `--patch`) | `@deepseek-ai/*` plugin ecosystem + cordis loader |
| `claude` | `binary` + provider runtime | Claude conversation/tooling client | provider-specific flags/env + config files | Claude-native tool integrations |
| `codex` | `binary` + API/SDK runtime | Codex-style coding agent/client | Codex command/API conventions | Codex plugin/agent integrations |
| `opencode` | project/tool runtime | Open-source/open-code tooling (opinionated) | its own config/command format | Tool-specific extension model |
| `pi` | varies | different tool family | depends on package implementation | different extension model |

When to choose this package:

- Use `deepseek-harness` if you need `dsh` CLI behavior and DeepSeek profile/plugin workflows.
- Use other tools if your environment is already built around their ecosystems and APIs.
- `deepseek-harness` here only fixes packaging/runtime launcher behavior for `dsh`; it does not reimplement those other tools.

## Quick selection guide

Use this when:

- You want to run `dsh` commands, especially `dsh web`.
- You need DeepSeek-specific profile/plugin workflows.
- You need a Nix-packaged, reproducible CLI launch wrapper.

Use another tool when:

- You need direct interaction with Claude/OpenAI Codex-style APIs.
- Your existing shell tooling and automation are already bound to those ecosystems.
- You want behavior specific to `opencode`/`pi` and their extension format.

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
