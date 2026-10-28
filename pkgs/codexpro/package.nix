{
  lib,
  buildNpmPackage,
  pkgs,
  nodejs,
}:

let
  sources = pkgs.callPackage ../../_sources/generated.nix { };
in
buildNpmPackage {
  pname = "codexpro";
  version = lib.removePrefix "v" sources.codexpro.version;
  inherit (sources.codexpro) src;

  npmDepsHash = "sha256-JCDEax05rgJ/cj+AOT5HRawzkvIwG2A/OcIMO5EFPYQ=";

  npmBuildScript = "build";

  inherit nodejs;

  meta = {
    description = "Self-hosted MCP server bridging ChatGPT Developer Mode to a local code workspace";
    homepage = "https://github.com/rebel0789/codexpro";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "codexpro";
  };

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -e "$out/lib/node_modules/codexpro/dist/http.js"
    test -e "$out/bin/codexpro-mcp-http"
    runHook postInstallCheck
  '';
}
