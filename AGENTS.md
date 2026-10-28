# Agent Guidelines for NUR Packages Repository

This repository contains Nix packages and NixOS modules not available in nixpkgs.

This file provides guidance to coding agents when working with code in this repository.

## Build Commands

```bash
# Enter development shell with tools
nix develop

# Available tools in dev shell:
# - nixfmt-rfc-style (code formatter)
# - nixd (language server)
# - statix (static analyzer/linter)

# Build specific package
nix build .#<package-name>
# Example: nix build .#hashtopolis-server

# Build default package
nix build .#default

# Update flake inputs
nix run .#update
```

## Code Style Guidelines

### File Structure
- Packages: `pkgs/<package-name>/package.nix`
- Modules: `modules/<module-name>/default.nix`
- Overlays: `overlays/<overlay-name>.nix`

### Imports & Parameters

**Packages**: Destructure all inputs explicitly
```nix
{
  lib,
  pkgs,
  stdenv,
  fetchFromGitHub,
  buildPythonPackage,
  ...
}:
```

**Modules**: Standard module signature
```nix
{ config, lib, pkgs, ... }:

with lib;
```

**Overlays**: Standard overlay signature
```nix
final: prev:
```

### Formatting
- Indentation: 2 spaces
- Use `with lib;` for modules to prefix lib functions
- Multi-line lists: consistent indentation
```nix
nativeBuildInputs = [
  makeWrapper
  autoPatchelfHook
];
```

### Naming Conventions
- Variables: camelCase (`dataDir`, `adminUser`, `packageName`)
- Options: camelCase with prefix matching service (`services.hashtopolis-server.enable`)
- Functions: camelCase (`mkEnableOption`, `mkIf`, `mkOption`)

### Package Definition Patterns

**Standard derivation**:
```nix
stdenv.mkDerivation {
  pname = "package-name";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "author";
    repo = "repo";
    rev = "v1.0.0";
    hash = "sha256-...";
  };

  buildInputs = [ ];
  nativeBuildInputs = [ ];

  meta = with lib; {
    description = "Short description";
    homepage = "https://example.com";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
```

**Using language-specific builders**:
```nix
php82.buildComposerProject2 { ... }
buildPythonPackage { ... }
```

**Platform filtering**:
```nix
package-name = if isLinux
  then pkgs.callPackage ./pkgs/package-name/package.nix { }
  else null;
```

### Module Definition Patterns

**Structure**:
```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.service-name;

  # Local definitions
  package = pkgs.callPackage ../../pkgs/service-name/package.nix { };
in {
  options.services.service-name = {
    enable = mkEnableOption "Service description";

    setting = mkOption {
      type = types.str;
      default = "default-value";
      description = "Setting description";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.service-name = {
      description = "Service Name";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${package}/bin/service";
        Restart = "always";
      };
    };
  };
}
```

### Overlay Patterns

**Simple override**:
```nix
final: prev: {
  myPackage = prev.myPackage.override { enableFeature = true; };
}
```

**OverrideAttrs**:
```nix
final: prev: {
  myPackage = prev.myPackage.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ dependency ];
  });
}
```

### Common Patterns

**Conditional packages**:
```nix
linuxPackages = lib.optionalAttrs isLinux {
  package1 = ...;
  package2 = ...;
};
```

**Source files**:
```nix
sources = import ../../_sources/generated.nix {
  inherit (pkgs) fetchFromGitHub fetchurl fetchgit;
};
```

**String concatenation for paths**:
```nix
${cfg.package}/share/application
${cfg.dataDir}/subdirectory
```

### Error Handling
- Use `lib.optionals` for conditional lists
- Use `mkIf` for conditional config
- Use `tryEval` for safe imports
- Platform checks: `stdenv.isLinux`, `lib.hasSuffix "linux" system`

### Meta Section
Always include:
```nix
meta = with lib; {
  description = "Concise one-line description";
  homepage = "https://project-url.com";
  license = licenses.<license>;  # Use from lib.licenses
  platforms = platforms.<platforms>;
  maintainers = [ ];  # Can add maintainers here
};
```

### Testing
- No automated test framework - build verification is testing
- Use `nix build .#<package>` to verify packages
- Check CI workflow: `.github/workflows/build.yml`

## Repository Structure Notes

- `pkgs/` - Package definitions (one directory per package)
- `modules/` - NixOS modules (services, system configurations)
- `overlays/` - Package overrides
- `templates/` - Project templates
- `_sources/` - Auto-generated from `nvfetcher.toml`

## Development Workflow

1. Create package in `pkgs/<name>/package.nix`
2. Add to `default.nix` or flake.nix packages list
3. Build: `nix build .#<name>`
4. Format: `nixfmt-rfc-style` (in dev shell)
5. Lint: `statix check` (in dev shell)
6. Update sources if needed: `nvfetcher -c nvfetcher.toml -o _sources`

## Important Notes

- Linux-only packages: Filter using `if isLinux then ... else null`
- Platform-specific packages listed in flake.nix: `falcon-sensor`, `feishu-lark`, etc.
- This is a NUR repository - packages not in nixpkgs
- Use `nixpkgs.config.allowUnfree = true` for unfree packages (e.g., falcon-sensor)

## What This Is

A NUR (Nix User Repository) containing Nix packages and NixOS modules not available in nixpkgs. Packages span security tools, blockchain nodes, developer utilities, enterprise apps, and system services.

## Build & Development Commands

```bash
nix develop                    # Dev shell with nixfmt-rfc-style, nixd, statix
nix build .#<package-name>     # Build a specific package
nix build .#default            # Build default package
nix run .#update               # Update flake inputs
nixfmt-rfc-style <file>        # Format Nix code (run inside dev shell)
statix check                   # Lint Nix code (run inside dev shell)
nvfetcher -c nvfetcher.toml -o _sources -k keyfile.toml  # Update auto-fetched sources (keyfile avoids GitHub 403)
```

There is no test framework; `nix build .#<package>` is the verification method.

## Architecture

### Key Files

- `flake.nix` — Flake entry point using `flake-parts` and `dream2nix`. Exposes packages, modules, templates, overlays, and dev shells for 3 systems (x86_64-linux, aarch64-linux, aarch64-darwin).
- `default.nix` — Package definitions used by flake outputs.
- `overlay.nix` — Standalone overlay using lazy evaluation. **Critical**: uses `prev` exclusively, no `rec`, no `with pkgs;`, no eager evaluation. See `OVERLAY_FIX.md` for why.
- `nvfetcher.toml` — Source fetching config; generates `_sources/generated.nix`.
- `modules/default.nix` — Index exporting all NixOS modules.

### Directory Layout

- `pkgs/<name>/package.nix` — Package definitions
- `modules/<name>/default.nix` — NixOS service modules
- `overlays/` — Package overrides
- `templates/` — Project templates (rust, python, go, java, nodejs, etc.)
- `_sources/` — Auto-generated by nvfetcher (do not edit manually)
- `achieves/` — Archived/historical package definitions

### Adding a New Package

1. Create `pkgs/<name>/package.nix`. That is the whole registration step:
   `pkgs/manifest.nix` discovers every directory under `pkgs/`, and
   `default.nix`, `overlay.nix` and `flake.nix` all derive their package lists
   from it — never add a package to those files by hand.
2. Declare `meta.platforms` honestly. It is the only place platform support is
   recorded: `default.nix` (and so the flake) filters on `lib.meta.availableOn`,
   so a package without `platforms` claims every system.
3. Build: `nix build .#<name>`
4. Format and lint before committing

Only two kinds of entry need hand-wiring, both documented in
`pkgs/manifest.nix`: directories holding several package definitions
(`pg-extensions/`, wired in `overlay.nix`), and packages needing extra
`callPackage` arguments (`falcon-sensor`). Rebuilds of *nixpkgs* packages —
`librime`, `wrangler`, the LDAP variants — are not under `pkgs/` and stay
written out in `default.nix` and `overlay.nix`. `sub2api` is re-exported from
the `llm-agents` flake input in `flake.nix`.

### Adding a New Module

1. Create `modules/<name>/default.nix`
2. Register in `modules/default.nix`
3. Reference the package via `pkgs.callPackage ../../pkgs/<name>/package.nix {}`
4. Use `*File` options for secrets (e.g., `adminPasswordFile`), never inline secrets

## Critical Patterns

### Overlay Safety (infinite recursion prevention)
The overlay must remain **purely lazy**. In `overlay.nix`:
- Use `prev` (never `final`) to reference existing packages
- No `rec` keyword, no `with pkgs;`
- No `import ./.` during overlay evaluation
- Platform checks evaluated at access time, not overlay application time

### Source Management
Packages using nvfetcher import sources like:
```nix
sources = import ../../_sources/generated.nix {
  inherit (pkgs) fetchFromGitHub fetchurl fetchgit;
};
```
Then merge: `stdenv.mkDerivation (sources.<pkg-name> // { ... })`

### Platform Filtering
Platform restrictions come solely from each package's `meta.platforms`; packages unavailable on a system are dropped from `default.nix`/flake outputs there. The overlay stays unfiltered (lazy) and nixpkgs raises its own platform error on access.

## CI/CD

- `.github/workflows/build.yml` — Builds on aarch64-linux, pushes to Cachix cache (`xiongchenyu6`), triggers NUR update. Runs daily at 2:51 UTC + on push to master.
- `.github/workflows/pr.yml` — Auto-creates PRs for feature/bugfix branches.

## Formatting & Style

- 2-space indentation, RFC-style formatting (`nixfmt-rfc-style`)
- Variables/options: camelCase (`dataDir`, `adminUser`)
- Packages: explicit parameter destructuring
- Modules: `with lib;` at top, `let cfg = config.services.<name>;` pattern
- Overlays: `final: prev:` signature
- Always include `meta` with description, homepage, license, platforms
