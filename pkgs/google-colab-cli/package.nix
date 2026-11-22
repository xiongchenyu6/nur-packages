{
  lib,
  fetchurl,
  python3Packages,
}:

let
  py = python3Packages;

  jupyter-mimetypes = py.buildPythonPackage rec {
    pname = "jupyter-mimetypes";
    version = "0.2.0";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/j/jupyter-mimetypes/jupyter_mimetypes-${version}-py3-none-any.whl";
      sha256 = "e6dcd989258e3fc944365b656d9173191517e0e393bd878e97ce500e5b388527";
    };

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

  jupyter-kernel-client = py.buildPythonPackage rec {
    pname = "jupyter-kernel-client";
    version = "0.9.0";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/j/jupyter-kernel-client/jupyter_kernel_client-${version}-py3-none-any.whl";
      sha256 = "77acb8f2f738d97625d6bd01ee8cf21c4d59790b7ba464108712db3870416f20";
    };

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
py.buildPythonApplication rec {
  pname = "google-colab-cli";
  version = "0.8.0";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/py3/g/google-colab-cli/google_colab_cli-${version}-py3-none-any.whl";
    sha256 = "5e623d0b34e6efa84ea81571d0cec60099e06aebe7ea345ec62f53e810da2ec1";
  };

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
    changelog = "https://github.com/googlecolab/google-colab-cli/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "colab";
    platforms = lib.platforms.all;
  };
}
