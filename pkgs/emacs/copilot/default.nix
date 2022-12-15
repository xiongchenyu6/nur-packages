{
  emacsPackagesFor,
  emacs,
  nodejs-16_x,
  source,
  ...
}: let
  epkgs = emacsPackagesFor emacs;
in
  epkgs.trivialBuild (source.copilot
    // {
      packageRequires = with epkgs; [s dash editorconfig nodejs-16_x];

      postInstall = ''
        cp -r dist $out/share/emacs/site-lisp
      '';

      doCheck = false;
    })
