{
  lib,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  grim,
  slurp,
}:

rustPlatform.buildRustPackage rec {
  pname = "computer-use-linux";
  version = "0.7.60";

  src = fetchFromGitHub {
    owner = "agent-sh";
    repo = "computer-use-linux";
    rev = "v${version}";
    hash = "sha256-k/Z5ZG91/NIo18VFDoMSBeMOh8WI1fWskpDvxRo0SPc=";
  };

  cargoHash = "sha256-u4VAVSAfIxwoS+rsArCBWJO1Rv8uNNP1p14Bat2rd2E=";

  nativeBuildInputs = [ makeWrapper ];

  # Upstream sets `lto = "fat"` + `codegen-units = 1`, which makes builds take
  # ~8 min; thin LTO cuts build time dramatically while keeping release speed.
  CARGO_PROFILE_RELEASE_LTO = "thin";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";

  # Unit tests exercise host dbus/wayland/proc/sh assumptions that do not hold
  # inside the Nix build sandbox; installCheckPhase verifies the built CLI.
  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/computer-use-linux \
      --suffix PATH : ${lib.makeBinPath [ grim slurp ]}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/computer-use-linux --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Native Linux desktop control over MCP and CLI (AT-SPI, Wayland/niri/Hyprland/GNOME/KDE/X11)";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    changelog = "https://github.com/agent-sh/computer-use-linux/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "computer-use-linux";
    platforms = lib.platforms.linux;
  };
}
