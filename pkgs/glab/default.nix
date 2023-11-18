{ lib, buildGoModule, fetchFromGitLab, installShellFiles, stdenv, source, ... }:
buildGoModule (source.glab // (let
  gops = (lib.importJSON ../../_sources/generated.json).glab;
  version = gops.version;
in {

  vendorHash = "sha256-x96ChhozvTrX0eBWt3peX8dpd4gyukJ28RkqcD2W/OM=";

  ldflags = [ "-s" "-w" "-X main.version=${version}" ];

  preCheck = ''
    # failed to read configuration:  mkdir /homeless-shelter: permission denied
    export HOME=$TMPDIR
  '';

  subPackages = [ "cmd/glab" ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall =
    lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''
      make manpage
      installManPage share/man/man1/*
      installShellCompletion --cmd glab \
        --bash <($out/bin/glab completion -s bash) \
        --fish <($out/bin/glab completion -s fish) \
        --zsh <($out/bin/glab completion -s zsh)
    '';

}))
