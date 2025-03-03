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
  epkgs = emacsPackagesFor emacs30;
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
  sources.magit-town
  // {
    propagatedBuildInputs = with epkgs; [ magit ];
    doCheck = false;
  }
)
