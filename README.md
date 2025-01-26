# nur-packages

**My personal [NUR](https://github.com/nix-community/NUR) repository**

![Build and populate cache](https://github.com/xiongchenyu6/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)
[![Cachix Cache](https://img.shields.io/badge/cachix-xiongchenyu6-blue.svg)](https://xiongchenyu6.cachix.org)

## Features

### Supported Systems

- x86_64-linux
- aarch64-linux
- aarch64-darwin
- x86_64-darwin

### Development Shell

Development environment includes:
- nixfmt-rfc-style - Nix code formatter
- nixd - Nix language server
- statix - Nix static analysis tool

### Update Command

Run `nix run .#update` to update flake inputs.

### Directory Structure

- `/pkgs` - Package definitions
- `/modules` - NixOS modules
- `/overlays` - Nixpkgs overlays
- `/templates` - Flake templates for various languages/frameworks including:
  - Bun
  - C/C++
  - CUDA
  - Empty
  - Go
  - Java
  - NixOS
  - Node.js
  - Python
  - Rust
  - Shell
  - Terraform
  - TEnv (Template Environment)

## Usage

### As a NixOS Module

```nix
{
  imports = [
    (import (builtins.fetchTarball {
      url = "https://github.com/xiongchenyu6/nur-packages/archive/main.tar.gz";
    }))
  ];
}
```

### For Individual Packages

```nix
{
  inputs.nur-xiongchenyu6.url = "github:xiongchenyu6/nur-packages";
  
  outputs = { self, nixpkgs, nur-xiongchenyu6 }: {
    # use the package
    environment.systemPackages = [
      nur-xiongchenyu6.packages.${system}.package-name
    ];
  };
}
