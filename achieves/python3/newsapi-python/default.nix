{ python3,  ... }:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) requests;
in buildPythonPackage (sources.newsapi-python // {
  propagatedBuildInputs = [ requests ];
  doCheck = false;
})
