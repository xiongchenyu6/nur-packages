{
  emacsPackagesFor,
  emacsNativeComp,
  source,
  ...
}: let
  epkgs = emacsPackagesFor emacsNativeComp;
in
  epkgs.trivialBuild (source.org-cv
    // rec {
      propagatedBuildInputs = with epkgs; [ox-hugo];

      doCheck = false;
    })
