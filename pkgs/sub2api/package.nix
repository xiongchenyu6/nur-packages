{
  pkgs,
  buildGoModule,
  buildNpmPackage,
  lib,
  ...
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

  version = sources.sub2api.version;

  frontend = buildNpmPackage {
    pname = "sub2api-frontend";
    inherit version;
    src = "${sources.sub2api.src}/frontend";
    npmDepsHash = "";
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGoModule (
  sources.sub2api
  // {
    modRoot = "backend";
    subPackages = [ "cmd/server" ];
    vendorHash = "";
    tags = [ "embed" ];
    ldflags = [
      "-s"
      "-w"
      "-X main.Version=${version}"
    ];
    doCheck = false;

    preBuild = ''
      cp -r ${frontend} internal/web/dist
    '';

    postInstall = ''
      mv $out/bin/server $out/bin/sub2api
    '';

    meta = with lib; {
      description = "AI API gateway platform for distributing subscription quotas";
      homepage = "https://github.com/Wei-Shaw/sub2api";
      license = licenses.mit;
      maintainers = [ ];
    };
  }
)
