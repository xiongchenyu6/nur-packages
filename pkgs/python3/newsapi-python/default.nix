{ python3, source, ... }:
let
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) requests;
in buildPythonPackage (source.newsapi-python // {
  propagatedBuildInputs = [ requests ];
  doCheck = false;
})
