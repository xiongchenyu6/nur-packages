{
  source,
  buildGoModule,
  pkgs,
}:
buildGoModule (source.amazon-cloudwatch-agent
  // {
    enableParallelBuilding = true;
    proxyVendor = true;
    vendorSha256 = "sha256-fS3vRmG3okxhKlf3gNrSemDrxPNj0o/apt7BNuZi8Kg=";

    ldflags = [
      "-s -w -X github.com/aws/amazon-cloudwatch-agent/cfg/agentinfo.VersionStr=1.247356.0 -X github.com/aws/amazon-cloudwatch-agent/cfg/agentinfo.BuildStr=2022-11-18T05:52:37Z"
    ];
    subPackages = [
      "cmd/amazon-cloudwatch-agent"
      "cmd/amazon-cloudwatch-agent-config-wizard"
      "cmd/config-downloader"
      "cmd/config-translator"
      "cmd/start-amazon-cloudwatch-agent"
    ];
  })
