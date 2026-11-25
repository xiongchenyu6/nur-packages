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
    "x86_64-linux" = sources.signoz-mcp-server-linux-x86_64;
    "aarch64-linux" = sources.signoz-mcp-server-linux-arm64;
    "x86_64-darwin" = sources.signoz-mcp-server-darwin-x86_64;
    "aarch64-darwin" = sources.signoz-mcp-server-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "signoz-mcp-server";
  inherit (platformSource) version src;

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    binPath="$(find . -maxdepth 3 -type f -name signoz-mcp-server | head -n1)"
    install -Dm755 "$binPath" "$out/bin/signoz-mcp-server"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/signoz-mcp-server" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Official SigNoz Model Context Protocol (MCP) server";
    homepage = "https://github.com/SigNoz/signoz-mcp-server";
    changelog = "https://github.com/SigNoz/signoz-mcp-server/releases/tag/v${platformSource.version}";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "signoz-mcp-server";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
