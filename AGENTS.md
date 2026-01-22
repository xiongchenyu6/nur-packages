# Agent Guidelines for NUR Packages Repository

This repository contains Nix packages and NixOS modules not available in nixpkgs.

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

- `pkgs/` - Package definitions (language-specific subdirectories for Emacs, Python, etc.)
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
