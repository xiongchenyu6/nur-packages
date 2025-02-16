{ lib, buildGoModule, installShellFiles, pkgs, }:
let 
  sources = import ../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
in
buildGoModule (sources.gitops // (let
  package_url = "github.com/weaveworks/weave-gitops";
  # these are likely not necessary

  flux_version = "0.37.0";
  dev_bucket_container_image =
    "ghcr.io/weaveworks/gitops-bucket-server@sha256:9fa2a68032b9d67197a3d41a46b5029ffdf9a7bc415e4e7e9794faec8bc3b8e4";
  tier = "oss";
  helm_chart_version = "4.0.11";
  gops = (lib.importJSON ../../_sources/generated.json).gitops;
  version = gops.version;
  src = gops.src;
in {

  vendorHash = "sha256-EV8MDHiQBmp/mEB+ug/yALPhcqytp0W8V6IPP+nt9DA=";

  subPackages = [ "cmd/gitops" ];

  ldflags = [
    "-X ${package_url}/cmd/gitops/version.Branch=releases/v${version}"
    "-X ${package_url}/cmd/gitops/version.BuildTime=1970-01-01_00:00:00"
    "-X ${package_url}/cmd/gitops/version.GitCommit=${src.rev}"
    "-X ${package_url}/cmd/gitops/version.Version=v${version}"
    # these are likely not necessary
    "-X ${package_url}/pkg/version.FluxVersion=${flux_version}"
    "-X ${package_url}/pkg/run/watch.DevBucketContainerImage=${dev_bucket_container_image}"
    "-X ${package_url}/pkg/analytics.Tier=${tier}"
    "-X ${package_url}/core/server.Branch=releases/v${version}"
    "-X ${package_url}/core/server.Buildtime=1970-01-01_00:00:00"
    "-X ${package_url}/core/server.GitCommit=${src.rev}"
    "-X ${package_url}/core/server.Version=v${version}"
    "-X ${package_url}/cmd/gitops/beta/run.HelmChartVersion=${helm_chart_version}"
  ];

  nativeBuildInputs = [ installShellFiles ];
  postInstall = ''
    installShellCompletion --cmd gitops \
      --bash <($out/bin/gitops completion bash --no-analytics) \
      --zsh <($out/bin/gitops completion zsh --no-analytics) \
      --fish <($out/bin/gitops completion fish --no-analytics)
  '';

  meta = with lib; {
    description = "Weave GitOps OSS";
    homepage = "https://docs.gitops.weave.works/docs/intro";
    changelog =
      "https://github.com/weaveworks/weave-gitops/releases/tag/v${version}";
    license = licenses.mpl20;
    platforms = platforms.unix;
  };
}))
