{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
}:

buildNpmPackage (finalAttrs: {
  pname = "deepseek-harness";
  version = "0.1.0-rc.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${finalAttrs.version}.tgz";
    hash = "sha256-L48Ldj1hGsU296lBHuQ8CvwGfBuHMsMQLATb45i8rMU=";
  };

  # Published package contains pre-built JavaScript artifacts in lib/ and no build hook is needed.
  dontNpmBuild = true;

  npmDepsHash = "sha256-Y+Y1f1V7+1sXkezKAeqEOW8GZeScERo/+gWXU4Qjqho=";
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  npmFlags = [ "--ignore-scripts" ];
  npmInstallFlags = [
    "--omit=dev"
    "--omit=optional"
    "--ignore-scripts"
  ];
  inherit nodejs_22;

  postInstall = ''
    header=$(head -n 1 "$out/bin/dsh")
    node_path=$(sed -n '2{s#^exec "\([^"]*node\)"[[:space:]]*.*#\1#;p;}' "$out/bin/dsh")
    script_args=$(sed -n '2{s#^exec "[^"]*node"[[:space:]]*##;p;}' "$out/bin/dsh")
    cat > "$out/bin/dsh" <<EOF_WRAP
$header
exec "$node_path" --expose-internals $script_args
EOF_WRAP
    chmod +x "$out/bin/dsh"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/dsh"
    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "CLI for DeepSeek Harness";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.1.0-rc.7";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "dsh";
  };
})
