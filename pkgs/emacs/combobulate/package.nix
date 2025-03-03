{
  pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  emacsPackagesFor,
  emacs30,
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
  epkgs = emacsPackagesFor emacs30;
in
epkgs.trivialBuild (
  sources.combobulate
  // rec {
    doCheck = false;
  }
)
