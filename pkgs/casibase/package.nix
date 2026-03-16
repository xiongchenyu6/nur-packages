{
  pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  lib,
  stdenv,
  autoPatchelfHook,
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
    "x86_64-linux" = sources.casibase-linux-x86_64;
    "aarch64-linux" = sources.casibase-linux-arm64;
    "x86_64-darwin" = sources.casibase-darwin-x86_64;
    "aarch64-darwin" = sources.casibase-darwin-arm64;
  };

  platformSource = platformSources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "casibase";
  version = platformSource.version;

  src = platformSource.src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc
  ];

  installPhase = ''
    mkdir -p $out/bin $out/web
    install -m755 casibase $out/bin/casibase
    cp -r web/build $out/web/
  '';

  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  meta = with lib; {
    description = "Open-source AI Cloud OS / knowledge management platform with Casdoor SSO";
    homepage = "https://casibase.org";
    license = licenses.asl20;
    platforms = builtins.attrNames platformSources;
    maintainers = [ "freeman" ];
  };
}
