{
  lib,
  buildGo122Module,
  fetchFromGitHub,
  installShellFiles,
  nix-update-script,
  source,
}:

buildGo122Module (
  source.sops
  // rec {
    pname = "sops";
    version = "3.9.3";

    vendorHash = "sha256-+UxngJgKG+gAjnXXEcdXPXQqRcMfRDn4wPeR1IhltC0=";

    postPatch = ''
      substituteInPlace go.mod \
        --replace-fail "go 1.22" "go 1.22.7"
    '';

    subPackages = [ "cmd/sops" ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/getsops/sops/v3/version.Version=${version}"
    ];

    passthru.updateScript = nix-update-script { };

    nativeBuildInputs = [ installShellFiles ];

    # postInstall = ''
    #   installShellCompletion --cmd sops --bash ${./bash_autocomplete}
    #   installShellCompletion --cmd sops --zsh ${./zsh_autocomplete}
    # '';

  }
)
