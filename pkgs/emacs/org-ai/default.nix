{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.org-ai // { doCheck = false; })

