{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dify-web";
  version = "1.13.1";

  src = fetchFromGitHub {
    owner = "langgenius";
    repo = "dify";
    tag = finalAttrs.version;
    hash = "sha256-hYok7YCw4SsLqunRpFjniErYBYPTh2RP53dFd8ujOOo=";
  };

  sourceRoot = "${finalAttrs.src.name}/web";

  nativeBuildInputs = [
    nodejs_22
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  pnpm = pnpm_10;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      sourceRoot
      pnpm
      ;
    fetcherVersion = 3;
    hash = "sha256-WYiBb1Itq1QTm2f5hR1hcyskiuGCZbsYiickkHE7WCs=";
  };

  env = {
    NEXT_TELEMETRY_DISABLED = "1";
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/dify-web
    # Copy standalone server files (may be at standalone/ or standalone/web/)
    if [ -d .next/standalone/web ]; then
      cp -r .next/standalone/web/. $out/lib/dify-web/
    else
      cp -r .next/standalone/. $out/lib/dify-web/
    fi
    # Copy full .next/ build output (BUILD_ID, routes-manifest.json, etc.)
    cp -r .next/. $out/lib/dify-web/.next/
    # Overwrite with standalone's own node_modules (don't use build-time ones)
    cp -r public $out/lib/dify-web/public

    mkdir -p $out/bin
    makeWrapper ${nodejs_22}/bin/node $out/bin/dify-web \
      --add-flags "$out/lib/dify-web/server.js" \
      --set PORT "3000" \
      --set HOSTNAME "0.0.0.0" \
      --set NODE_ENV "production"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Dify web frontend - open-source LLM application platform";
    homepage = "https://github.com/langgenius/dify";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
})
