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
    "x86_64-linux" = sources.unity-cli-linux-x64;
    "aarch64-linux" = sources.unity-cli-linux-arm64;
    "x86_64-darwin" = sources.unity-cli-darwin-x64;
    "aarch64-darwin" = sources.unity-cli-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "unity-cli";
  inherit (platformSource) version src;

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ (lib.getLib stdenv.cc.cc) ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/unity

    runHook postInstall
  '';

  # Stripping destroys the Deno payload appended to the ELF; patchelf alone is safe.
  dontStrip = true;

  # No execution-based installCheck: the binary segfaults inside the Nix build
  # sandbox even when intact (runs fine outside it).

  meta = with lib; {
    description = "Unity command-line interface for managing editors, projects, builds and tests";
    homepage = "https://docs.unity.com/en-us/unity-cli";
    license = licenses.unfree;
    maintainers = [ ];
    mainProgram = "unity";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
