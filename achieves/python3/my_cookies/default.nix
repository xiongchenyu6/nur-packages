{ python3, ... }:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) browser-cookie3;
in buildPythonPackage (sources.my_cookies // rec {
  propagatedBuildInputs = [ browser-cookie3 ];
  doCheck = false;
})
