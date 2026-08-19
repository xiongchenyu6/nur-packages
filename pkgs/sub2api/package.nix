{
  pkgs,
  buildGo126Module,
  stdenvNoCC,
  pnpm_10,
  nodejs,
  lib,
  pnpmConfigHook,
  fetchPnpmDeps,
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

    # The hook and the fetcher have to be built against the same pnpm as the
    # one on PATH. Left at their defaults they follow whatever `pnpm` points at
    # (11.x today), which rejects this lockfile's fetcherVersion.
    nativeBuildInputs = [
      pnpm_10
      (pnpmConfigHook.override { pnpm = pnpm_10; })
      nodejs
    ];

    pnpmDeps = (fetchPnpmDeps.override { pnpm = pnpm_10; }) {
      pname = "sub2api-frontend";
      inherit version;
      src = "${sources.sub2api.src}/frontend";
      hash = "sha256-Yyn2/2+np0jf/o+i6hl/GD9MxksBLRQSyjr7wplQ7I8=";
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

    # Upstream pins a go patch release (e.g. `go 1.26.6`) that nixpkgs may not
    # have yet; only the minor matters, so drop the patch component.
    postPatch = ''
      sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' backend/go.mod
    '';

    vendorHash = "sha256-kmtkj9L1qMupQpc2E0Gbx9a3xPZ9o9bFrtwrbLoAB3w=";
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
