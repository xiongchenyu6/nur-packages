{
  pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  emacsPackagesFor,
  emacs,
  ...
}:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
  epkgs = emacsPackagesFor emacs;
in
epkgs.trivialBuild (
  sources.combobulate
  // rec {
    doCheck = false;
  }
)
