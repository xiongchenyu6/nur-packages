{ pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  emacsPackagesFor,
  emacs29,
  ...
}:
let epkgs = emacsPackagesFor emacs29;
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
in epkgs.trivialBuild (sources.magit-town // {
  propagatedBuildInputs = with epkgs; [ magit ];
  doCheck = false;
})
