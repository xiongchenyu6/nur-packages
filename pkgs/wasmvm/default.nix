{ rustPlatform, lib, source, ... }:
let bin = "bttc";
in rustPlatform.buildRustPackage ({
  pname = source.wasmvm.pname;
  version = source.wasmvm.version;
  src = "${source.wasmvm.src}/libwasmvm";
  enableParallelBuilding = true;
  proxyVendor = true;
  cargoSha256 = "sha256-N2LBLp5rFgX8GqHkYqGcgcMsa+VPfLfl31ILesCwkG4=";
  doCheck = false;

  postInstall = "mv $out/lib/libwasmvm.so $out/lib/libwasmvm.x86_64.so";
})
