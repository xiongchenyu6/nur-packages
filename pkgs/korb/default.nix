{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.korb // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorHash = "sha256-SHAoQtjqds2EqJmyYZEtG2e7gUw87lYevqS7ZFK4Fc0=";
  doCheck = false;
  nativeBuildInputs = [ tree installShellFiles ];
  # postInstall = ''
  #   mv $out/bin/main $out/bin/korb
  # '';
})
# patchelf --set-interpreter ${wasmvm}/lib/libwasmvm.x86_64.so $out/bin/core

