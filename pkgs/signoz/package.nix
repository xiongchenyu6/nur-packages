{
  lib,
  pkgs,
  stdenv,
  makeWrapper,
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
    "x86_64-linux" = sources.signoz-linux-x86_64;
    "aarch64-linux" = sources.signoz-linux-arm64;
    "x86_64-darwin" = sources.signoz-darwin-x86_64;
    "aarch64-darwin" = sources.signoz-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "signoz";
  inherit (platformSource) version src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/signoz $out/bin/signoz
    mkdir -p $out/share/signoz
    cp -r web templates conf $out/share/signoz/
    install -Dm644 LICENSE $out/share/licenses/signoz/LICENSE
    install -Dm644 README.md $out/share/doc/signoz/README.md

    wrapProgram $out/bin/signoz \
      --set-default SIGNOZ_WEB_DIRECTORY "$out/share/signoz/web" \
      --set-default SIGNOZ_ALERTMANAGER_SIGNOZ_TEMPLATES "$out/share/signoz/templates/alertmanager/*.gotmpl" \
      --set-default SIGNOZ_EMAILING_TEMPLATES_DIRECTORY "$out/share/signoz/templates/email"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/signoz --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Open-source OpenTelemetry-native observability platform (Community Edition)";
    homepage = "https://signoz.io";
    changelog = "https://github.com/SigNoz/signoz/releases/tag/v${platformSource.version}";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "signoz";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
