{
  emacsPackagesFor,
  emacsUnstable,
  source,
  ...
}: let
  epkgs = emacsPackagesFor emacsUnstable;
in
  epkgs.trivialBuild (source.ligature
    // rec {
      doCheck = false;
    })
