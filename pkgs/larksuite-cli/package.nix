{
  lib,
  pkgs,
  stdenv,
}:

let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      dockerTools
      fetchFromGitHub
      fetchgit
      fetchurl
      ;
  };

  platformSources = {
    "x86_64-linux" = sources.larksuite-cli-linux-x86_64;
    "aarch64-linux" = sources.larksuite-cli-linux-arm64;
    "riscv64-linux" = sources.larksuite-cli-linux-riscv64;
    "x86_64-darwin" = sources.larksuite-cli-darwin-x86_64;
    "aarch64-darwin" = sources.larksuite-cli-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "larksuite-cli";
  inherit (platformSource) version src;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 lark-cli $out/bin/lark-cli
    install -Dm644 LICENSE $out/share/licenses/larksuite-cli/LICENSE
    install -Dm644 README.md $out/share/doc/larksuite-cli/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/larksuite-cli/CHANGELOG.md

    runHook postInstall
  '';

  dontFixup = stdenv.hostPlatform.isLinux;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    HOME=$TMPDIR $out/bin/lark-cli --version | grep -F "lark-cli version ${platformSource.version}"

    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "Command-line tool for Lark and Feishu open platform APIs";
    homepage = "https://github.com/larksuite/cli";
    changelog = "https://github.com/larksuite/cli/blob/v${platformSource.version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lark-cli";
    platforms = builtins.attrNames platformSources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
