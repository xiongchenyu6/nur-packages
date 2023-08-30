{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.combobulate // rec { doCheck = false; })
