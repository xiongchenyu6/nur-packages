{ lib, buildGoModule, fetchFromGitHub, fetchzip, installShellFiles, stdenv
, source }:

let
  fluxcd = (lib.importJSON ../../_sources/generated.json).fluxcd;
  version = fluxcd.version;
in buildGoModule (source.fluxcd // {

  vendorHash = "sha256-ifzzNEFXq2VzidaxCTdz7VZOCoA0zPcK6uL0CyBNrE4=";

  postUnpack = ''
    mkdir -p source/cmd/flux/manifests
    tar xvf ${source.fluxcd-manifest.src} --directory=source/cmd/flux/manifests
    ls source/cmd/flux

    # disable tests that require network access
    rm source/cmd/flux/create_secret_git_test.go
  '';

  ldflags = [ "-s" "-w" "-X main.VERSION=${version}" ];

  subPackages = [ "cmd/flux" ];

  # Required to workaround test error:
  #   panic: mkdir /homeless-shelter: permission denied
  HOME = "$TMPDIR";

  nativeBuildInputs = [ installShellFiles ];

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/flux --version | grep ${version} > /dev/null
  '';

  postInstall =
    lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''
      for shell in bash fish zsh; do
        $out/bin/flux completion $shell > flux.$shell
        installShellCompletion flux.$shell
      done
    '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description =
      "Open and extensible continuous delivery solution for Kubernetes";
    longDescription = ''
      Flux is a tool for keeping Kubernetes clusters in sync
      with sources of configuration (like Git repositories), and automating
      updates to configuration when there is new code to deploy.
    '';
    homepage = "https://fluxcd.io";
    license = licenses.asl20;
    maintainers = with maintainers; [ bryanasdev000 jlesquembre ];
    mainProgram = "flux";
  };
})
