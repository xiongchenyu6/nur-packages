{ emacsPackagesFor, emacsGitNativeComp, lib, source, ... }:

let
  epkgs = emacsPackagesFor emacsGitNativeComp;
  # cleanBrokenFileFilter = name: type: !(((baseNameOf name) == "acm-backend-telega.el") || ((baseNamef name) == "acm-backend-tempel.el"));
  acm = epkgs.trivialBuild {
    pname = "acm";
    # src = lib.cleanSourceWith
    #   {
    #     filter = cleanBrokenFileFilter;
    src = source.lsp-bridge.src + "/acm";
    # };
    packageRequires = with epkgs; [ yasnippet ];

  };
in
epkgs.trivialBuild (source.lsp-bridge // rec {
  propagatedBuildInputs = with epkgs; [ posframe markdown-mode yasnippet acm ];
  subPackages = [ "acm" ];

  doCheck = false;
})
