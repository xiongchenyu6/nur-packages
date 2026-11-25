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
    "x86_64-linux" = sources.rustdesk-api-linux-x86_64;
    "aarch64-linux" = sources.rustdesk-api-linux-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "rustdesk-api";
  inherit (platformSource) version src;

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 release/apimain "$out/bin/rustdesk-api"
    mkdir -p "$out/share/rustdesk-api/resources"
    cp -r release/conf "$out/share/rustdesk-api/"
    cp -r release/resources/{admin,i18n,public,templates,version} "$out/share/rustdesk-api/resources/"
    runHook postInstall
  '';

  meta = with lib; {
    description = "RustDesk API server with address books, management UI and OIDC authentication";
    homepage = "https://github.com/lejianwen/rustdesk-api";
    changelog = "https://github.com/lejianwen/rustdesk-api/releases/tag/v${platformSource.version}";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "rustdesk-api";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
