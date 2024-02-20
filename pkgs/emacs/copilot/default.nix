{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.copilot-el // {
  packageRequires = with epkgs; [ s f dash editorconfig ];

  postInstall = ''
    cp -r dist $out/share/emacs/site-lisp
  '';

  doCheck = false;
})
