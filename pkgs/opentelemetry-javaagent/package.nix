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
  pname = "opentelemetry-javaagent";
  inherit (sources.opentelemetry-javaagent) version src;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/share/java/opentelemetry-javaagent.jar"
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenTelemetry Java automatic bytecode instrumentation agent";
    homepage = "https://github.com/open-telemetry/opentelemetry-java-instrumentation";
    changelog = "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/tag/v${sources.opentelemetry-javaagent.version}";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.all;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
  };
}
