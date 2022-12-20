{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.ligature // rec { doCheck = false; })
