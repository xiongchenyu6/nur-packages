{
  python3,
  source,
  ...
}: let
  inherit (python3.pkgs) buildPythonPackage;
in
  buildPythonPackage (source.pem
    // {
      doCheck = false;
    })
