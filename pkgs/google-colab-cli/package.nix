{
  lib,
  pkgs,
  python3Packages,
}:

let
  py = python3Packages;
  sources = pkgs.callPackage ../../_sources/generated.nix { };

  jupyter-mimetypes = py.buildPythonPackage {
    pname = "jupyter-mimetypes";
    inherit (sources.jupyter-mimetypes) version src;
    format = "wheel";

    dependencies = with py; [
      pyarrow
      typing-extensions
    ];

    pythonImportsCheck = [ "jupyter_mimetypes" ];

    meta = {
      description = "MIME type helpers for Jupyter";
      homepage = "https://github.com/datalayer/jupyter-mimetypes";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.all;
    };
  };

  jupyter-kernel-client = py.buildPythonPackage {
    pname = "jupyter-kernel-client";
    inherit (sources.jupyter-kernel-client) version src;
    format = "wheel";

    dependencies =
      (with py; [
        jupyter-client
        jupyter-core
        requests
        traitlets
        typing-extensions
        websocket-client
      ])
      ++ [ jupyter-mimetypes ];

    pythonImportsCheck = [ "jupyter_kernel_client" ];

    meta = {
      description = "Client to interact with a Jupyter Kernel";
      homepage = "https://github.com/datalayer/jupyter-kernel-client";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.all;
    };
  };
in
py.buildPythonApplication {
  pname = "google-colab-cli";
  inherit (sources.google-colab-cli) version src;
  format = "wheel";

  dependencies =
    (with py; [
      click
      filelock
      google-auth
      google-auth-oauthlib
      html2text
      keyring
      nbformat
      packaging
      prompt-toolkit
      pydantic
      pygments
      requests
      rich
      typer
      typing-extensions
      websocket-client
    ])
    ++ [ jupyter-kernel-client ];

  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "colab_cli" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/bin/colab --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI for interacting with Google Colab runtimes";
    homepage = "https://github.com/googlecolab/google-colab-cli";
    changelog = "https://github.com/googlecolab/google-colab-cli/blob/v${sources.google-colab-cli.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "colab";
    platforms = lib.platforms.all;
  };
}
