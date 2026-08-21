# Single source of truth for the package definitions under pkgs/.
#
# default.nix, overlay.nix and flake.nix all derive their package lists from
# here. They used to each carry a hand-written list, which drifted: 16 of the
# 30 packages were missing from default.nix — the file NUR itself evaluates —
# so they were invisible to NUR consumers while still building fine via the
# flake.
#
# Platform support is NOT tracked here. Every package already declares
# meta.platforms, and nixpkgs refuses to evaluate a derivation outside them, so
# consumers filter with `lib.meta.availableOn` instead of consulting a second,
# always-stale list.
{ lib }:
let
  entries = builtins.readDir ./.;

  # Directories holding several package definitions rather than one plain
  # callPackage target. Their consumers wire them up by hand.
  composite = [
    "dify"
    "emacs"
    "pg-extensions"
  ];

  # falcon-sensor's directory-level default.nix chooses between a stub, a URL
  # fetch and requireFile based on the environment, and needs `builtins` passed
  # through to do it. Every other package is a plain package.nix.
  specialEntry = {
    falcon-sensor = {
      path = ./falcon-sensor;
      args = {
        inherit builtins;
      };
    };
  };

  isPackageDir = name: entries.${name} == "directory" && !(builtins.elem name composite);
in
rec {
  names = builtins.filter isPackageDir (builtins.attrNames entries);

  entryOf =
    name:
    specialEntry.${name} or {
      path = ./. + "/${name}/package.nix";
      args = { };
    };

  # Lazily map every package through the caller's callPackage. Values stay
  # unevaluated until accessed, which is what keeps overlay.nix free of the
  # eager evaluation that caused the infinite recursion described in
  # OVERLAY_FIX.md.
  callAll =
    callPackage:
    lib.genAttrs names (
      name:
      let
        entry = entryOf name;
      in
      callPackage entry.path entry.args
    );

  # Same, but restricted to packages whose meta.platforms covers `platform`.
  # Reading meta does not trip nixpkgs' platform check, so this is safe to call
  # on a system the package does not support.
  callAvailable =
    platform: callPackage:
    lib.filterAttrs (_: drv: lib.meta.availableOn platform drv) (callAll callPackage);
}
