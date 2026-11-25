{
  lib,
  pkgs,
  stdenv,
  unzip,
  autoPatchelfHook,
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

  platformSources = {
    "x86_64-linux" = sources.rustdesk-server-api-linux-x86_64;
    "aarch64-linux" = sources.rustdesk-server-api-linux-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "rustdesk-server-api";
  inherit (platformSource) version src;

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    for prog in hbbr hbbs rustdesk-utils; do
      binPath="$(find . -maxdepth 3 -type f -name "$prog" | head -n1)"
      install -Dm755 "$binPath" "$out/bin/$prog"
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "RustDesk rendezvous and relay servers with rustdesk-api JWT authentication";
    homepage = "https://github.com/lejianwen/rustdesk-server";
    changelog = "https://github.com/lejianwen/rustdesk-server/releases/tag/v${platformSource.version}";
    license = licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "hbbs";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
