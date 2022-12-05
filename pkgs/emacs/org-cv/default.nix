{
  emacsPackagesFor,
  emacsUnstable,
  source,
  ...
}: let
  epkgs = emacsPackagesFor emacsUnstable;
in
  epkgs.trivialBuild (source.org-cv
    // rec {
      propagatedBuildInputs = with epkgs; [ox-hugo];

      doCheck = false;
    })
