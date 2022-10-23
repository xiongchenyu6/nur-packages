{ python3, lib, source, ... }:
let
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) python-ldap;
  inherit (python3.pkgs) flask;
in buildPythonPackage (source.Flask-SimpleLDAP // rec {
  propagatedBuildInputs = [ python-ldap flask ];
  doCheck = false;
})
