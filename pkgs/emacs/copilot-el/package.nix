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
