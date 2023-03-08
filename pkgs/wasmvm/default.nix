{ rustPlatform, lib, source, ... }:
rustPlatform.buildRustPackage ({
  pname = source.wasmvm.pname;
  version = source.wasmvm.version;
  src = "${source.wasmvm.src}/libwasmvm";
  enableParallelBuilding = true;
  proxyVendor = true;
  cargoSha256 = "sha256-FsmXYubWTmR6iL7w1T0DfDv2UMtm2pYB0ujPUA1Ljd0=";
  doCheck = false;

  postInstall = "mv $out/lib/libwasmvm.so $out/lib/libwasmvm.x86_64.so";
})
