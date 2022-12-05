{
  python3,
  source,
  pem,
  ...
}: let
  inherit (python3.pkgs) buildPythonPackage pyopenssl requests django;
in
  buildPythonPackage (source.django-sns-view
    // {
      propagatedBuildInputs = [django requests pem pyopenssl];
      doCheck = false;
    })
