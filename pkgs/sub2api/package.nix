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

    # The frontend imports legal markdown from the repo-root `docs/legal`
    # directory (e.g. `../../../../docs/legal/admin-compliance.zh.md?raw`),
    # which lives outside the `frontend/` source root. Make it available
    # as a sibling of the build root before Vite resolves the imports.
    preBuild = ''
      cp -r ${sources.sub2api.src}/docs ../docs
      chmod -R u+w ../docs
    '';

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

    # go.mod pins a go patch release newer than the one nixpkgs ships;
    # relax the directive so the available toolchain is accepted.
    postPatch = ''
      substituteInPlace backend/go.mod --replace-fail "go 1.26.4" "go 1.26.3"
    '';

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
