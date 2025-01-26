{ pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  emacsPackagesFor,
  emacs29,
  ...
}:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (sources.combobulate // rec {
  doCheck = false;
})
