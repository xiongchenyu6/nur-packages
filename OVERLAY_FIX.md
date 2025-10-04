# NUR Overlay Fix Summary

## Problem
The NUR overlay was causing **infinite recursion** when used in nix-darwin and NixOS configurations. The error manifested as:
```
error: infinite recursion encountered
at /nix/store/.../pkgs/top-level/by-name-overlay.nix:58:20
```

Additionally, there was a **platform mismatch** issue where the overlay was hardcoded to use `x86_64-linux` packages on all systems.

## Root Causes

### 1. Infinite Recursion
The overlay was importing `default.nix` during nixpkgs evaluation, which:
- Used `with pkgs;` bringing all packages into scope
- Had `rec` in the package set creating recursive references
- Called `pkgs.callPackage` and accessed packages during the overlay definition (not lazily)
- This caused nixpkgs's `by-name-overlay.nix` to trigger during stdenv bootstrap, creating infinite recursion

### 2. Platform Mismatch
- The flake overlay was referencing `self.packages.x86_64-linux` regardless of the actual system
- `default.nix` also had hardcoded references to `x86_64-linux` packages

## Solution

### Created `overlay.nix`
A **standalone overlay file** that:
1. **Uses lazy evaluation** - Packages are only evaluated when accessed, not during overlay definition
2. **Uses `prev` (super) exclusively** - Never references `final` to avoid circular dependencies
3. **Direct package definitions** - Each package is defined directly in the overlay without intermediate variables
4. **Platform-aware** - Linux-only packages throw errors on non-Linux systems (caught during evaluation, not during overlay application)
5. **No recursion** - No `rec`, no `with pkgs;`, no eager evaluation

### Key Changes

#### Before (broken):
```nix
# In flake.nix
overlays.default = final: prev:
  let
    packages = import ./. { pkgs = prev; };  # ❌ Imports during evaluation
  in packages;

# In default.nix
with pkgs;  # ❌ Brings all packages into scope
rec {       # ❌ Creates recursive references
  default = librime;  # ❌ References within same set
}
```

#### After (working):
```nix
# In overlay.nix
final: prev: {
  librime = (prev.librime.override {  # ✅ Direct definition using prev
    plugins = [ ... ];
  }).overrideAttrs ...;
  
  wrangler = prev.wrangler.overrideAttrs ...;  # ✅ Lazy evaluation
  
  # Linux-only packages with runtime checks
  cyrus_sasl_with_ldap = 
    if lib.hasPrefix "linux" prev.system then
      prev.callPackage ...
    else
      throw "...only available on Linux";  # ✅ Fails at access time, not overlay time
}
```

### File Structure
```
nur-packages/
├── flake.nix           # Points to overlay.nix
├── overlay.nix         # ✅ NEW: Standalone overlay (lazy, uses prev only)
├── default.nix         # Still used for flake packages output
└── pkgs/               # Individual package definitions
```

## Benefits

1. **✅ No infinite recursion** - Works in overlays for nixpkgs, nix-darwin, and NixOS
2. **✅ Platform-aware** - Automatically adapts to the current system
3. **✅ Lazy evaluation** - Packages only evaluated when accessed
4. **✅ Clean separation** - Overlay logic separate from package definitions
5. **✅ Maintainable** - Easy to add new packages following the same pattern

## Testing

### Test overlay works
```bash
nix eval --impure --expr 'let 
  overlay = (builtins.getFlake (toString ./.)).overlays.default; 
  pkgs = import <nixpkgs> { overlays = [ overlay ]; }; 
in pkgs.librime.name'
```

### Test in nix-darwin
```bash
darwin-rebuild build --flake .#your-host --impure
```

### Available packages (aarch64-darwin)
```
gotron-sdk
helmify
korb
ldap-extra-schemas
librime
my2sql
wrangler
```

### Linux-only packages (throw on macOS)
```
cyrus_sasl_with_ldap
falcon-sensor
feishu-lark
haystack-editor
ldap-passthrough-conf
openldap_with_cyrus_sasl
postfix_with_ldap
record_screen
sssd_with_sude
sudo_with_sssd
sui
```

## Migration Guide

### For users of this NUR
No changes needed! The overlay still works the same way:
```nix
{
  nixpkgs.overlays = [
    inputs.xiongchenyu6.overlays.default
  ];
}
```

### For maintainers adding new packages

1. Add package definition to `pkgs/your-package/package.nix`
2. Add entry to `overlay.nix`:
   ```nix
   your-package = prev.callPackage ./pkgs/your-package/package.nix { };
   ```
3. For Linux-only packages:
   ```nix
   your-package = 
     if lib.hasPrefix "linux" prev.system then
       prev.callPackage ./pkgs/your-package/package.nix { }
     else
       throw "your-package is only available on Linux";
   ```
4. The package will automatically be available in `self.packages.${system}`

## Technical Details

### Why this works
- **Lazy evaluation**: Nix only evaluates attribute values when accessed
- **No circular references**: Using `prev` means we reference the "previous" package set, not the final one being constructed
- **No eager imports**: We don't call `import ./.` or evaluate packages during overlay definition
- **Platform checks at runtime**: The `if lib.hasPrefix "linux"` is evaluated when the package is accessed, not when the overlay is applied

### Why the old approach failed
- `import ./.` with `pkgs = prev` still caused evaluation during stdenv bootstrap
- `with pkgs;` created references to the entire package set
- `rec` created self-referential attribute sets
- Accessing `self.packages` in the overlay created circular dependency with flake outputs

## Conclusion

The overlay now works correctly on all platforms without infinite recursion. The key insight is that overlays must be **purely lazy** - they should only define how to build packages, not actually build or evaluate them during nixpkgs initialization.
