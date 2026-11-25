{
  lib,
  pkgs,
  stdenvNoCC,
}:

let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      dockerTools
      fetchFromGitHub
      fetchgit
      fetchurl
      ;
  };
in
stdenvNoCC.mkDerivation {
  pname = "mathesar";
  inherit (sources.mathesar) version src;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    tar -xzf "$src" -C "$out"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Intuitive spreadsheet-like interface for PostgreSQL databases";
    homepage = "https://mathesar.org";
    changelog = "https://github.com/mathesar-foundation/mathesar/releases/tag/${sources.mathesar.version}";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
