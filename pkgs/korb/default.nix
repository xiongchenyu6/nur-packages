{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.korb // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorHash = "sha256-/wuMwEm1E46FlePmEWBwHTgVmeo4hdI6QPFywrnO0NY=";
  doCheck = false;
  nativeBuildInputs = [ tree installShellFiles ];
  # postInstall = ''
  #   mv $out/bin/main $out/bin/korb
  # '';
})
# patchelf --set-interpreter ${wasmvm}/lib/libwasmvm.x86_64.so $out/bin/core

