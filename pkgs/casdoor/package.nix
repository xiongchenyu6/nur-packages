{
  lib,
  stdenv,
  pkgs,
  autoPatchelfHook,
}:
let
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  platformSource =
    {
      x86_64-linux = sources.casdoor-linux-x86_64;
      aarch64-linux = sources.casdoor-linux-arm64;
      x86_64-darwin = sources.casdoor-darwin-x86_64;
      aarch64-darwin = sources.casdoor-darwin-arm64;
    }
    .${stdenv.hostPlatform.system};
  staticAssets = sources.casdoor-static.src;

in
stdenv.mkDerivation {
  pname = "casdoor";
  inherit (platformSource) version src;

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

    # Bundle static assets so they can be served locally
    # instead of requiring cdn.casbin.org (which may be blocked)
    cp -r ${staticAssets}/img $out/web/build/
    cp -r ${staticAssets}/flag-icons $out/web/build/
    cp -r ${staticAssets}/site $out/web/build/
  '';

  dontConfigure = true;
  dontBuild = true;
  dontPatch = true;

  meta = with lib; {
    description = "A Django-like Go/React login web UI that supports OAuth, OIDC, SAML, CAS, LDAP, etc.";
    homepage = "https://casdoor.org";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ "freeman" ];
  };
}
