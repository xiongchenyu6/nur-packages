{ emacsPackagesFor, emacs29, source, ... }:
let epkgs = emacsPackagesFor emacs29;
in epkgs.trivialBuild (source.chatgpt-arcana // {
  packageRequires = with epkgs; [ request markdown-mode dash ];
  doCheck = false;
})
