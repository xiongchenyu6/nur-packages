{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.helmify // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorHash = "sha256-WME1hMPAih6q3RXyCAkBiKZ6TBnaCcuWf+B1DdlvT+o=";
  doCheck = false;
})
