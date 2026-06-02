{
  pkgs,
  buildGo126Module,
  stdenvNoCC,
  pnpm_10,
  nodejs,
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

  frontend = stdenvNoCC.mkDerivation {
    pname = "sub2api-frontend";
    inherit version;
    src = "${sources.sub2api.src}/frontend";

    nativeBuildInputs = [
      pnpm_10.configHook
      nodejs
    ];

    pnpmDeps = pnpm_10.fetchDeps {
      pname = "sub2api-frontend";
      inherit version;
      src = "${sources.sub2api.src}/frontend";
      hash = "sha256-1ShAwutwXzRp3qd4oe/jw8WAyKpr+WIm9610rJwgIiQ=";
      fetcherVersion = 3;
    };

    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r ../backend/internal/web/dist $out
      runHook postInstall
    '';
  };
in
buildGo126Module (
  sources.sub2api
  // {
    modRoot = "backend";
    subPackages = [ "cmd/server" ];
    vendorHash = "sha256-rfv0MEUx2IXf3GsDVVZhEIyvKAW0L68tyzbrP5f4iqk=";
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
