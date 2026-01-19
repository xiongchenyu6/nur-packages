{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "2.253.0";
  passthru.platforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
in
stdenv.mkDerivation {
  pname = "casdoor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/casdoor/casdoor/releases/download/v${version}/casdoor_Linux_x86_64.tar.gz";
    hash = "sha256-quPcr7Ff9D077fp9gUz50/D1+Ejz0AO4cSwQzDW3bEA=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -m755 casdoor $out/bin/casdoor
  '';

  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  meta = with lib; {
    description = "A Django-like Go/React login web UI that supports OAuth, OIDC, SAML, CAS, LDAP, etc.";
    homepage = "https://casdoor.org";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = [ "freeman" ];
  };
}
