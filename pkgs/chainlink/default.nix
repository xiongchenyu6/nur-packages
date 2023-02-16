{ buildGoModule, lib, source, wasmvm, pkg-config, patchelf, ... }:
buildGoModule (source.chainlink // {
  buildInputs = [ wasmvm ];
  nativeBuildInputs = [ pkg-config patchelf ];
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-S5wtKuOsQ4S1ePoqFn7qbck7Hdnrj7UA0SJu3NvUtAM=";
  subPackages = [ "core" ];
  doCheck = false;
  COMMIT_SHA = "$(shell git rev-parse HEAD)";
  VERSION = "$(shell cat VERSION)";
  ldflags = [
    "-X github.com/smartcontractkit/chainlink/core/static.Version=${
      lib.removePrefix "v"
      (lib.importJSON ../../_sources/generated.json).chainlink.version
    }"
    "-X github.com/smartcontractkit/chainlink/core/static.Sha=${
      (lib.importJSON ../../_sources/generated.json).chainlink.src.sha256
    }"
  ];
  preBuild = ''
    set -x
    tar xvf ${source.operator-ui.src}
    ls
    mkdir -p ./core/web/assets
    cp package/artifacts/* ./core/web/assets/
  '';

  postInstall = ''
    patchelf --remove-rpath $out/bin/core
    mv $out/bin/core $out/bin/chainlink
  '';
  postFixup =
    "patchelf --set-rpath ${lib.makeLibraryPath [ wasmvm ]} $out/bin/chainlink";
})
# patchelf --set-interpreter ${wasmvm}/lib/libwasmvm.x86_64.so $out/bin/core

