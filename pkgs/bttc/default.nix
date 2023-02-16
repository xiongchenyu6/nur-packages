{ buildGoModule, lib, source, ... }:
let bin = "bttc";
in buildGoModule (source.bttc // rec {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-O56F2n9tdzsYBNCoPMgo3bVo2qbRyI25iIcKTKx4s/8=";
  subPackages = [ "cmd/geth" "cmd/bootnode" ];
  doCheck = false;
  postInstall = "mv $out/bin/geth $out/bin/${bin}";
  meta = with lib; {
    homepage = "https://www.bttc.com/";
    description = "Official golang implementation of the Bttc protocol";
    license = with licenses; [ lgpl3Plus gpl3Plus ];
    maintainers = with maintainers; [ adisbladis lionello RaghavSood ];
  };
})
