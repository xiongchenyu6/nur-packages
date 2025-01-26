{ python3, ... }:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) sexpdata;
in buildPythonPackage (sources.epc // rec {
  propagatedBuildInputs = [ sexpdata ];
  doCheck = false;
})
