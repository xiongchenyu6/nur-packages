{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "2.253.0";

  sources = {
    "x86_64-linux" = {
      url = "https://github.com/casdoor/casdoor/releases/download/v${version}/casdoor_Linux_x86_64.tar.gz";
      hash = "sha256-quPcr7Ff9D077fp9gUz50/D1+Ejz0AO4cSwQzDW3bEA=";
    };
    "aarch64-linux" = {
      url = "https://github.com/casdoor/casdoor/releases/download/v${version}/casdoor_Linux_arm64.tar.gz";
      hash = "sha256-/EMRJUK4R9ZeWUGRsY7+cxclEo+/nSzn+Q8WsUE9Ydk=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/casdoor/casdoor/releases/download/v${version}/casdoor_Darwin_x86_64.tar.gz";
      hash = "sha256-KBJ037k3/w084PZ3P1Ous5lO/ABmEVOscn5N4BDpVe8=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/casdoor/casdoor/releases/download/v${version}/casdoor_Darwin_arm64.tar.gz";
      hash = "sha256-V1Anymw638S1YocuLSXZVNOpJgiueIoi8Q/b7hmbh2s=";
    };
  };
in
stdenv.mkDerivation {
  pname = "casdoor";
  inherit version;

  src = fetchurl sources.${stdenv.hostPlatform.system};

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc
  ];

  installPhase = ''
    mkdir -p $out/bin $out/web
    install -m755 casdoor $out/bin/casdoor
    cp -r web/build $out/web/
  '';

  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  meta = with lib; {
    description = "A Django-like Go/React login web UI that supports OAuth, OIDC, SAML, CAS, LDAP, etc.";
    homepage = "https://casdoor.org";
    license = licenses.asl20;
    platforms = builtins.attrNames sources;
    maintainers = [ "freeman" ];
  };
}
