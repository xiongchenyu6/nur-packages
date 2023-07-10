{ lib, stdenv, autoPatchelfHook, source, ... }:
stdenv.mkDerivation (source.my2sql // rec {

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  phases = [ "installPhase" ]; # Removes all phases except installPhase

  installPhase = ''
    set -e
    mkdir -p $out/bin
    install -m755 -D ${source.my2sql.src} $out/bin/my2sql
  '';
})
