{
  emacsPackagesFor,
  emacs29,
  source,
  ...
}:
let
  epkgs = emacsPackagesFor emacs29;
in
epkgs.trivialBuild (
  source.copilot-chat
  // {
    packageRequires = with epkgs; [ markdown-mode ];

    # postInstall = ''
    #   ls assets
    #   cp -r dist $out/share/emacs/site-lisp
    # '';

    doCheck = false;
  }
)
