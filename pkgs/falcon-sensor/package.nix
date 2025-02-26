{
  stdenv,
  lib,
  pkgs,
  dpkg,
  openssl,
  libnl,
  zlib,
  fetchurl,
  autoPatchelfHook,
  buildFHSEnv,
  writeScript,
  ...
}:
let
  pname = "falcon-sensor";
  version = "7.21";
  arch = "amd64";
  src = ./falcon-sensor_7.21_amd64.deb;
  falcon-sensor = stdenv.mkDerivation {
    inherit version arch src;
    name = pname;

    buildInputs = [
      dpkg
      zlib
      autoPatchelfHook
    ];

    sourceRoot = ".";

    unpackPhase = ''dpkg-deb -x $src .                                                                                                                                 '';

    installPhase = ''cp -r . $out                                                                                                                              '';

    meta = with lib; {
      description = "Crowdstrike Falcon Sensor";
      homepage = "https://www.crowdstrike.com/";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = with maintainers; [ klden ];
    };
  };
in
buildFHSEnv {
  name = "fs-bash";
  targetPkgs = pkgs: [
    libnl
    openssl
    zlib
  ];

  extraInstallCommands = ''ln -s ${falcon-sensor}/* $out/                                                                                                                           '';

  runScript = "bash";
}
