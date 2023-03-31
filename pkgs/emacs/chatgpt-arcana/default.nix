{ emacsPackagesFor, emacs, source, ... }:
let epkgs = emacsPackagesFor emacs;
in epkgs.trivialBuild (source.chatgpt-arcana // {
  packageRequires = with epkgs; [ request markdown-mode dash ];
  doCheck = false;
})
