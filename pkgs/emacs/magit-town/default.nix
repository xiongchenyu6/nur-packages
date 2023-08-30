{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.magit-town // {
  propagatedBuildInputs = with epkgs; [ magit ];
  doCheck = false;
})
