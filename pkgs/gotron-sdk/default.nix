{ buildGoModule, tree, lib, source, installShellFiles, pkg-config, patchelf, ...
}:
buildGoModule (source.gotron-sdk // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-GhdT0RQkIkV0wjgtRUdUmN7UZyVd0XGyGkmZn30PqG4=";
  doCheck = false;
  nativeBuildInputs = [ tree installShellFiles ];
  ldflags = [
    "-X  main.version==${
      (lib.importJSON ../../_sources/generated.json).gotron-sdk.version
    }"
    "-X main.commit=${
      (lib.importJSON ../../_sources/generated.json).gotron-sdk.src.rev
    }"
  ];
  postInstall = ''
    mv $out/bin/cmd $out/bin/tronctl
  '';
  installCheckPhase = "";
})
# patchelf --set-interpreter ${wasmvm}/lib/libwasmvm.x86_64.so $out/bin/core

