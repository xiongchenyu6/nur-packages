{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.magit-gitflow // {
  propagatedBuildInputs = with epkgs; [ magit magit-popup ];

  doCheck = false;
})
