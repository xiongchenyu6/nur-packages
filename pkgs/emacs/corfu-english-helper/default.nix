{ lib, emacsPackagesFor, emacs, nodejs-16_x, source, ... }:
let
  epkgs = emacsPackagesFor emacs;
  file-path = builtins.split "/" (toString ./.);
  pkgName = lib.last file-path;
in epkgs.trivialBuild (source."${pkgName}" // {
  propagatedBuildInputs = with epkgs; [ corfu ];
  doCheck = false;
})
