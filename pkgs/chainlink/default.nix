{ buildGoModule, lib, source, wasmvm, pkg-config, patchelf, ... }:
let bin = "bttc";
in buildGoModule (source.chainlink // rec {
  buildInputs = [ wasmvm ];
  nativeBuildInputs = [ pkg-config patchelf ];
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-S5wtKuOsQ4S1ePoqFn7qbck7Hdnrj7UA0SJu3NvUtAM=";
  subPackages = [ "core" ];
  doCheck = false;
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

