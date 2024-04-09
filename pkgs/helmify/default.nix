{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.helmify // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorHash = "sha256-FmgAHHpHH8D7YVvysAEI34nRHBgjhy9JFkYeBOYjSm8=";
  doCheck = false;
})
