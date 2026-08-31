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
    "x86_64-linux" = sources.codex-acp-linux-x86_64;
    "aarch64-linux" = sources.codex-acp-linux-arm64;
    "x86_64-darwin" = sources.codex-acp-darwin-x86_64;
    "aarch64-darwin" = sources.codex-acp-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "codex-acp: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex-acp";
  inherit (platformSource) version src;

  # tarball 顶层就是 codex-acp 和 codex-resources/,没有包一层目录。
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 codex-acp $out/bin/codex-acp
    # bwrap 沙箱辅助文件,codex-acp 按相对路径找它。
    if [ -d codex-resources ]; then
      mkdir -p $out/bin/codex-resources
      cp -a codex-resources/. $out/bin/codex-resources/
    fi

    runHook postInstall
  '';

  # Linux 取的是 musl 版:静态链接(没有 .interp),不需要 autoPatchelfHook,
  # 也不依赖本机的 nix-ld。
  dontPatchELF = true;
  dontStrip = true;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/codex-acp --help > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Agent Client Protocol server for OpenAI Codex";
    homepage = "https://github.com/zed-industries/codex-acp";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "codex-acp";
  };
}
