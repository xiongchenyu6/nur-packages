{
  lib,
  pkgs,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  git,
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
    "x86_64-linux" = sources.happier-cli-linux-x86_64;
    "aarch64-linux" = sources.happier-cli-linux-arm64;
    "x86_64-darwin" = sources.happier-cli-darwin-x86_64;
    "aarch64-darwin" = sources.happier-cli-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "happier-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "happier-cli";
  inherit (platformSource) version src;

  # 上游 tarball 顶层是 happier-<version>-<platform>/,解开后直接用那一层。
  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # `happier` 本身是自带 node 运行时的 ELF 单文件,node_modules 里还有一批
  # 原生模块(node-pty / sharp / onnxruntime 之类)的 .node。autoPatchelfHook
  # 递归把它们的 interpreter 和 RPATH 修到 nix store 里。
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  # 上游把可选的原生模块也塞进 node_modules,里面有为别的 libc / 别的架构
  # 准备的 .node(例如 musl 版)。autoPatchelf 修不动它们,但运行时也不会加载
  # ——不忽略的话整个构建会失败。
  autoPatchelfIgnoreMissingDeps = true;

  installPhase = ''
    runHook preInstall

    root=$(echo happier-*-*)
    mkdir -p $out/lib/happier-cli
    cp -a "$root"/. $out/lib/happier-cli/

    mkdir -p $out/bin
    # `happier` 这个 ELF **不是 CLI 本身,是打包进来的 bun 运行时**
    # (见 package-dist/.build-manifest.json 的 runtimeAsset:直接跑它
    # `--version` 会输出 bun 的版本 1.3.5、`happier service` 会报
    # "Script not found")。真正的入口是 package-dist/index.mjs,得让运行时去跑它。
    makeWrapper $out/lib/happier-cli/happier $out/bin/happier \
      --add-flags $out/lib/happier-cli/package-dist/index.mjs \
      --prefix PATH : ${lib.makeBinPath [ git ]}

    runHook postInstall
  '';

  meta = {
    description = "Mobile/Web client CLI for Claude Code, Codex, OpenCode and friends";
    homepage = "https://happier.dev";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "happier";
  };
}
