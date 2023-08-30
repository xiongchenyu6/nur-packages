{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.magit-gitflow // {
  propagatedBuildInputs = with epkgs; [ magit magit-popup ];
  doCheck = false;
})
