{ pkgs, python3, ... }:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) python-ldap;
  inherit (python3.pkgs) flask;
in buildPythonPackage (sources.Flask-SimpleLDAP // rec {
  propagatedBuildInputs = [ python-ldap flask ];
  doCheck = false;
})
