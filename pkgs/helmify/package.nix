{pkgs, buildGoModule, tree, lib, installShellFiles, pkg-config, patchelf, ...
}:
let 
  sources = import ../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
in
buildGoModule (sources.helmify // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorHash = "sha256-WME1hMPAih6q3RXyCAkBiKZ6TBnaCcuWf+B1DdlvT+o=";
  doCheck = false;
})
