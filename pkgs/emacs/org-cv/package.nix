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
  epkgs = emacsPackagesFor emacs;
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
in
epkgs.trivialBuild (
  sources.org-cv
  // {
    propagatedBuildInputs = with epkgs; [
      ox-hugo
      dash
    ];

    doCheck = false;
  }
)
