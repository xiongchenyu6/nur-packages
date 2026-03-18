{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_22,
  pnpm_10,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dify-web";
  version = "1.13.1";

  src = fetchFromGitHub {
    owner = "langgenius";
    repo = "dify";
    tag = finalAttrs.version;
    hash = lib.fakeHash;
  };

  sourceRoot = "${finalAttrs.src.name}/web";

  nativeBuildInputs = [
    nodejs_22
    pnpm_10.configHook
    makeWrapper
  ];

  pnpmDeps = pnpm_10.fetchDeps {
    inherit (finalAttrs)
      pname
      version
      src
      sourceRoot
      ;
    hash = lib.fakeHash;
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
    cp -r .next/standalone/web/* $out/lib/dify-web/
    cp -r .next/static $out/lib/dify-web/.next/static
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
