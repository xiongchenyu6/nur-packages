{
  lib,
  stdenv,
  pkgs,
}:

let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
  platformSources = {
    x86_64-linux = sources.camber-linux-x86_64;
    aarch64-linux = sources.camber-linux-arm64;
    aarch64-darwin = sources.camber-darwin-arm64;
  };
  source = platformSources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "camber";
  inherit (source) version src;

  sourceRoot = ".";

  unpackPhase = ''
    tar xzf $src
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 camber $out/bin/camber

    runHook postInstall
  '';

  dontFixup = stdenv.hostPlatform.isLinux;

  meta = with lib; {
    description = "CLI for Camber Cloud platform";
    homepage = "https://cambercloud.com";
    license = licenses.unfree;
    maintainers = [ ];
    mainProgram = "camber";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
