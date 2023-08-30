{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.org-cv // {
  propagatedBuildInputs = with epkgs; [ ox-hugo ];

  doCheck = false;
})
