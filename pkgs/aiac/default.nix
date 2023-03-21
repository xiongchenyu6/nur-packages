{ buildGoModule, lib, source, ... }:
buildGoModule (source.aiac // {
  enableParallelBuilding = true;
  proxyVendor = true;
  vendorSha256 = "sha256-/+EVQ6mRbAaB7dlKQGR1YSAm8aUKQqJjE0R+XM6nbgc=";
  doCheck = false;
  meta = with lib; {
    homepage = "https://www.bttc.com/";
    description = "Official golang implementation of the Bttc protocol";
    license = with licenses; [ lgpl3Plus gpl3Plus ];
    maintainers = with maintainers; [ adisbladis lionello RaghavSood ];
  };
})
