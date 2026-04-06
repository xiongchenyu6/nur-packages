{
  pkgs,
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
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
in
buildNpmPackage (
  sources.cc-gateway
  // {
    npmDepsHash = "sha256-dyf00BVjNsE+3xom5fO3m8Me0K4MirRXAyYYDh7tVms=";

    nodejs = nodejs_22;

    nativeBuildInputs = [ makeWrapper ];

    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/{bin,lib/cc-gateway}

      cp -r dist $out/lib/cc-gateway/
      cp -r node_modules $out/lib/cc-gateway/
      cp package.json $out/lib/cc-gateway/

      makeWrapper ${nodejs_22}/bin/node $out/bin/cc-gateway \
        --add-flags "$out/lib/cc-gateway/dist/index.js"

      runHook postInstall
    '';

    meta = with lib; {
      description = "HTTP/HTTPS gateway for Claude Code traffic";
      homepage = "https://github.com/motiful/cc-gateway";
      license = licenses.mit;
      maintainers = [ ];
      mainProgram = "cc-gateway";
      platforms = platforms.all;
    };
  }
)
