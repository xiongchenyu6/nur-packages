{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.copilot // {
  packageRequires = with epkgs; [ s dash editorconfig ];

  postInstall = ''
    cp -r dist $out/share/emacs/site-lisp
  '';

  doCheck = false;
})
