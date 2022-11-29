{
  php,
  php81Packages,
  curl,
  stdenv,
  git,
  source,
  lib,
  ...
}:
stdenv.mkDerivation (source.oci-arm-host-capacity
  // rec {
    enableParallelBuilding = true;
    buildInputs = [curl php php81Packages.composer];

    preInstallPhase = ''
      curl www.baidu.com

    '';

    installPhase = ''
      composer install
      mkdir -p $out/bin
      cp vendor src index.php $out
    '';

    propagatedBuildInputs = [git];

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    meta = with lib; {
      homepage = "https://www.bttc.com/";
      description = "Official golang implementation of the Bttc protocol";
      license = with licenses; [lgpl3Plus gpl3Plus];
      maintainers = with maintainers; [adisbladis lionello RaghavSood];
    };
  })
