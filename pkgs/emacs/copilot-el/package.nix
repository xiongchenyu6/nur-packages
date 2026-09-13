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
  sources.copilot-el
  // {
    packageRequires = with epkgs; [
      s
      f
      dash
      editorconfig
    ];

    # postInstall = ''
    #   ls assets
    #   cp -r dist $out/share/emacs/site-lisp
    # '';

    doCheck = false;
  }
)
