{
  pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  lib,
  stdenv,
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };

  # v2.x releases are single, statically-linked Go binaries (one per platform).
  # The web frontend, default config and skills are all embedded in the binary,
  # so there is nothing else to unpack or bundle.
  platformSources = {
    "x86_64-linux" = sources.openagent-linux-x86_64;
    "aarch64-linux" = sources.openagent-linux-arm64;
    "x86_64-darwin" = sources.openagent-darwin-x86_64;
    "aarch64-darwin" = sources.openagent-darwin-arm64;
  };

  platformSource = platformSources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "openagent";
  version = platformSource.version;

  src = platformSource.src;

  # src is a bare (statically-linked) binary, not an archive.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  installPhase = ''
    runHook preInstall
    install -D -m755 $src $out/bin/openagent
    runHook postInstall
  '';

  meta = with lib; {
    description = "Next-generation personal AI assistant powered by LLM, RAG and agent loops (formerly Casibase)";
    homepage = "https://www.openagentai.org/";
    license = licenses.asl20;
    platforms = builtins.attrNames platformSources;
    maintainers = [ "freeman" ];
    mainProgram = "openagent";
  };
}
