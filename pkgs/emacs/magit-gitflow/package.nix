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
  sources.magit-gitflow
  // {
    propagatedBuildInputs = with epkgs; [
      magit
      magit-popup
    ];

    doCheck = false;
  }
)
