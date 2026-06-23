{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

buildNpmPackage (finalAttrs: {
  pname = "codexpro";
  version = "0.28.5";

  # Upstream publishes no git tags/releases; pin the commit that carries the
  # 0.28.5 package.json.
  src = fetchFromGitHub {
    owner = "rebel0789";
    repo = "codexpro";
    rev = "7d971fcb2b7ee2afc990d1e65984d408191dd46e";
    hash = "sha256-vavPYnMXvhgAqcmM2PPBnww5WR9Q/WxcA9YQAe6tspI=";
  };

  npmDepsHash = "sha256-7fX/tLUvKJTdXxYs+OOQ8hLXyXXnsClZrgmjQ3mEI8Q=";

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
})
