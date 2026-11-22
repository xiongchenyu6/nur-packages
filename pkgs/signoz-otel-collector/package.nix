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
    "x86_64-linux" = sources.signoz-otel-collector-linux-x86_64;
    "aarch64-linux" = sources.signoz-otel-collector-linux-arm64;
    "x86_64-darwin" = sources.signoz-otel-collector-darwin-x86_64;
    "aarch64-darwin" = sources.signoz-otel-collector-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "signoz-otel-collector";
  inherit (platformSource) version src;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/signoz-otel-collector $out/bin/signoz-otel-collector
    mkdir -p $out/share/signoz-otel-collector
    cp -r conf $out/share/signoz-otel-collector/

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/signoz-otel-collector --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "SigNoz OpenTelemetry Collector with ClickHouse exporters and schema migrator";
    homepage = "https://github.com/SigNoz/signoz-otel-collector";
    changelog = "https://github.com/SigNoz/signoz-otel-collector/releases/tag/v${platformSource.version}";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "signoz-otel-collector";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
