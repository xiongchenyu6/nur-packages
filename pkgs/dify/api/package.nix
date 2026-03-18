{
  lib,
  stdenv,
  makeWrapper,
  difyApiEnv,
  dify-src,
  python312,
  postgresql,
  libffi,
  openssl,
}:

stdenv.mkDerivation {
  pname = "dify-api";
  version = "1.13.1";

  src = dify-src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    # Install API source code
    mkdir -p $out/lib/dify-api/app
    cp -r api/* $out/lib/dify-api/app/

    # Install the Python virtual environment
    ln -s ${difyApiEnv} $out/lib/dify-api/venv

    # Create wrapper scripts
    mkdir -p $out/bin

    # Common environment setup
    cat > $out/lib/dify-api/env.sh <<'ENVEOF'
    export PYTHONPATH="$DIFY_APP_DIR"
    export PATH="${difyApiEnv}/bin:${postgresql}/bin:$PATH"
    ENVEOF

    # dify-api: gunicorn server (bind/workers/worker-class passed by startup script)
    makeWrapper ${difyApiEnv}/bin/gunicorn $out/bin/dify-api \
      --prefix PATH : "${lib.makeBinPath [ postgresql ]}" \
      --set PYTHONPATH "$out/lib/dify-api/app" \
      --run "cd $out/lib/dify-api/app" \
      --add-flags "--timeout 200" \
      --add-flags "app:app"

    # dify-worker: celery worker
    makeWrapper ${difyApiEnv}/bin/celery $out/bin/dify-worker \
      --prefix PATH : "${lib.makeBinPath [ postgresql ]}" \
      --set PYTHONPATH "$out/lib/dify-api/app" \
      --run "cd $out/lib/dify-api/app" \
      --add-flags "-A celery_entrypoint.celery" \
      --add-flags "worker" \
      --add-flags "-P gevent" \
      --add-flags "-Q dataset,generation,mail,ops_trace,plugin"

    # dify-beat: celery beat scheduler
    makeWrapper ${difyApiEnv}/bin/celery $out/bin/dify-beat \
      --prefix PATH : "${lib.makeBinPath [ postgresql ]}" \
      --set PYTHONPATH "$out/lib/dify-api/app" \
      --run "cd $out/lib/dify-api/app" \
      --add-flags "-A app.celery" \
      --add-flags "beat"

    # dify-migrate: flask migration command
    makeWrapper ${difyApiEnv}/bin/flask $out/bin/dify-migrate \
      --prefix PATH : "${lib.makeBinPath [ postgresql ]}" \
      --set PYTHONPATH "$out/lib/dify-api/app" \
      --run "cd $out/lib/dify-api/app" \
      --add-flags "upgrade-db"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Dify API server - open-source LLM application platform";
    homepage = "https://github.com/langgenius/dify";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
