{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "1.0.26";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://cli.cambercloud.com/releases/${version}/cambercli_${version}_Linux_x86_64.tar.gz";
      hash = "sha256-vYbIOW/cj1ULb6ERbio3ux85AGhJGT0WAXZ8EV+wC9I=";
    };
    aarch64-linux = fetchurl {
      url = "https://cli.cambercloud.com/releases/${version}/cambercli_${version}_Linux_arm64.tar.gz";
      hash = "sha256-TbBb9ESCbOjhBgDEHarv3qNMzMMldvMCUg4B8GhxJ24=";
    };
    x86_64-darwin = fetchurl {
      url = "https://cli.cambercloud.com/releases/${version}/cambercli_${version}_Darwin_x86_64.tar.gz";
      hash = "sha256-IRwU4eMTOMxa7kY66Yg3jlKdbrCRQIKDtaGsGOc/CNQ=";
    };
    aarch64-darwin = fetchurl {
      url = "https://cli.cambercloud.com/releases/${version}/cambercli_${version}_Darwin_arm64.tar.gz";
      hash = "sha256-TWQN3gBKkNUZdq9Rwxf3Oe2ZCovYRSRU0L+wcep3+J8=";
    };
  };
in
stdenv.mkDerivation {
  pname = "camber";
  inherit version;

  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

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
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
