{ emacsPackagesFor, emacsNativeComp, lib, source, ... }:

let
  epkgs = emacsPackagesFor emacsNativeComp;
in
epkgs.trivialBuild (source.ligature // rec {
  doCheck = false;
})
