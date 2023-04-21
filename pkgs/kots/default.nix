{ lib, stdenv, autoPatchelfHook, source, ... }:
stdenv.mkDerivation (source.kots // rec {

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    set -e
    mkdir -p $out/bin
    tar xvf ${source.kots.src}
    install -m755 -D kots $out/bin/kots
  '';
})
