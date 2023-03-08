{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.magit-town // {
  propagatedBuildInputs = with epkgs; [ magit ];
  doCheck = false;
})
