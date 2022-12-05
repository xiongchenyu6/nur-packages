{
  python3,
  source,
  ...
}: let
  inherit (python3.pkgs) buildPythonPackage;
in
  buildPythonPackage (source.django-ordered-model
    // {
      doCheck = false;
    })
