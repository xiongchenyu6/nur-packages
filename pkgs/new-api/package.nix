{
  lib,
  pkgs,
  stdenv,
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
    "x86_64-linux" = sources.new-api-linux-x86_64;
    "aarch64-linux" = sources.new-api-linux-arm64;
    "aarch64-darwin" = sources.new-api-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "new-api";
  inherit (platformSource) version src;

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/new-api"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Unified LLM API gateway and model asset management system";
    homepage = "https://github.com/QuantumNous/new-api";
    changelog = "https://github.com/QuantumNous/new-api/releases/tag/v${platformSource.version}";
    license = licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "new-api";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
