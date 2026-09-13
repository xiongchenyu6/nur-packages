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
  sources.gptel
  // {
    # gptel.el declares: (transient "0.7.8") (compat "30.1.0.0"). Leaving this
    # empty meant byte-compilation fell back to the transient bundled with
    # Emacs, which predates the :environment slot gptel-rewrite.el uses.
    packageRequires = with epkgs; [
      transient
      compat
    ];

    # postInstall = ''
    #   ls assets
    #   cp -r dist $out/share/emacs/site-lisp
    # '';

    doCheck = false;
  }
)
