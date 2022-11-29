{
  emacsPackagesFor,
  emacsNativeComp,
  nodejs-16_x,
  source,
  ...
}: let
  epkgs = emacsPackagesFor emacsNativeComp;
in
  epkgs.trivialBuild (source.copilot
    // rec {
      packageRequires = with epkgs; [s dash editorconfig nodejs-16_x];

      postInstall = ''
        cp -r dist $out/share/emacs/site-lisp
      '';

      doCheck = false;
    })
