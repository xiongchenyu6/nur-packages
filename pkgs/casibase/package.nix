{
  pkgs,
  fetchgit,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  lib,
  stdenv,
  autoPatchelfHook,
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

  platformSources = {
    "x86_64-linux" = sources.casibase-linux-x86_64;
    "aarch64-linux" = sources.casibase-linux-arm64;
    "x86_64-darwin" = sources.casibase-darwin-x86_64;
    "aarch64-darwin" = sources.casibase-darwin-arm64;
  };

  platformSource = platformSources.${stdenv.hostPlatform.system};

  # Static assets (logos, flags, icons) from casdoor/static GitHub repo
  # These are normally served from cdn.casibase.org which may be blocked in some networks
  staticAssets = fetchFromGitHub {
    owner = "casdoor";
    repo = "static";
    rev = "576df3db5344e7357fcbf33a463b8f9647cb97b7";
    hash = "sha256-k9p8/3RXC6uKsm7+ALa1pWKq5HdSOfoZP1nKV4H4MPg=";
  };
in
stdenv.mkDerivation {
  pname = "casibase";
  version = platformSource.version;

  src = platformSource.src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc
  ];

  installPhase = ''
    mkdir -p $out/bin $out/web $out/data
    install -m755 casibase $out/bin/casibase
    cp -r web/build $out/web/
    cp -r data/* $out/data/

    # Bundle static assets so they can be served locally
    # instead of requiring cdn.casibase.org (which may be blocked)
    cp -r ${staticAssets}/img $out/web/build/
    cp -r ${staticAssets}/flag-icons $out/web/build/
  '';

  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  meta = with lib; {
    description = "Open-source AI Cloud OS / knowledge management platform with Casdoor SSO";
    homepage = "https://casibase.org";
    license = licenses.asl20;
    platforms = builtins.attrNames platformSources;
    maintainers = [ "freeman" ];
  };
}
