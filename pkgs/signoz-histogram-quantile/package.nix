{
  lib,
  pkgs,
  stdenv,
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
    "x86_64-linux" = sources.signoz-histogram-quantile-linux-x86_64;
    "aarch64-linux" = sources.signoz-histogram-quantile-linux-arm64;
    "x86_64-darwin" = sources.signoz-histogram-quantile-darwin-x86_64;
    "aarch64-darwin" = sources.signoz-histogram-quantile-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "signoz-histogram-quantile";
  inherit (platformSource) version src;

  sourceRoot = ".";

  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 histogram-quantile $out/bin/histogramQuantile
    ln -s histogramQuantile $out/bin/histogram-quantile
    install -Dm644 LICENSE $out/share/licenses/signoz-histogram-quantile/LICENSE
    install -Dm644 README.md $out/share/doc/signoz-histogram-quantile/README.md

    runHook postInstall
  '';

  meta = with lib; {
    description = "ClickHouse executable user-defined function for SigNoz histogram quantile queries";
    homepage = "https://github.com/SigNoz/signoz";
    changelog = "https://github.com/SigNoz/signoz/releases/tag/histogram-quantile%2Fv${platformSource.version}";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "histogramQuantile";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
