{ python3, ... }:
let inherit (python3.pkgs) buildPythonPackage;
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
in buildPythonPackage (sources.pem // { doCheck = false; })
