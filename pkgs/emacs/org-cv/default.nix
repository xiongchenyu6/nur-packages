{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.org-cv // {
  propagatedBuildInputs = with epkgs; [ ox-hugo ];

  doCheck = false;
})
