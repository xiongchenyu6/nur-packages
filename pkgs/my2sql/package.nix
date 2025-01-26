{ pkgs,lib, stdenv, autoPatchelfHook,... }:
let 
  sources = import ../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
in
stdenv.mkDerivation (sources.my2sql // rec {

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  phases = [ "installPhase" ]; # Removes all phases except installPhase

  installPhase = ''
    set -e
    mkdir -p $out/bin
    install -m755 -D ${sources.my2sql.src} $out/bin/my2sql
  '';
})
