{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.helmify // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-8t8AouSVOG4aMMCCmz/N86l7I3iTAa2aVReGyhdgKls=";
  doCheck = false;
})
