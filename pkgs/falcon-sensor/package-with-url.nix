# Alternative falcon-sensor package that can download from a URL
# Usage: Set FALCON_SENSOR_URL environment variable to the download URL
{
  stdenv,
  lib,
  pkgs,
  dpkg,
  openssl,
  libnl,
  zlib,
  fetchurl,
  autoPatchelfHook,
  buildFHSEnv,
  writeScript,
  ...
}:
let
  pname = "falcon-sensor";
  version = "7.30.0";
  release = "18306";
  arch = "amd64";

  # SHA256 hash of the .deb file
  debSha256 = "25faf5ae428ba0e0b67cf075401fd1310df57651424e2bfe742ff7b4711ba422";

  # Check if user provided a URL
  userProvidedUrl = builtins.getEnv "FALCON_SENSOR_URL";

  # If URL is provided, download it; otherwise use requireFile
  src = if userProvidedUrl != "" then
    fetchurl {
      url = userProvidedUrl;
      sha256 = debSha256;
      name = "falcon-sensor_${version}-${release}_${arch}.deb";
    }
  else
    # For public/mirror URLs (if you have one)
    fetchurl {
      # Example URLs - replace with actual if available
      urls = [
        # Option 1: Direct URL if you have one
        # "https://your-mirror.com/falcon-sensor_${version}-${release}_${arch}.deb"

        # Option 2: Private repository
        # "https://your-private-repo.com/falcon-sensor_${version}-${release}_${arch}.deb"

        # Option 3: S3 bucket or other storage
        # "s3://your-bucket/falcon-sensor_${version}-${release}_${arch}.deb"

        # Fallback: local file URL
        "file:///tmp/falcon-sensor_${version}-${release}_${arch}.deb"
      ];
      sha256 = debSha256;

      # If all URLs fail, show this message
      postFetch = ''
        if [ ! -f "$out" ]; then
          echo "========================================"
          echo "Failed to download Falcon Sensor"
          echo "========================================"
          echo ""
          echo "Please either:"
          echo "1. Set FALCON_SENSOR_URL environment variable:"
          echo "   export FALCON_SENSOR_URL='https://your-url/falcon-sensor.deb'"
          echo "   nix build .#falcon-sensor --impure"
          echo ""
          echo "2. Or download manually and place at:"
          echo "   /tmp/falcon-sensor_${version}-${release}_${arch}.deb"
          echo ""
          echo "3. Or use the manual method from README.md"
          exit 1
        fi
      '';
    };

  falcon-sensor = stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib
      zlib
    ];

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out

      # Move lib to usr/lib to match FHS expectations
      if [ -d "lib" ]; then
        mkdir -p $out/usr/lib
        cp -r lib/* $out/usr/lib/
      fi

      # Copy other directories
      if [ -d "opt/CrowdStrike" ]; then
        mkdir -p $out/opt
        cp -r opt/CrowdStrike $out/opt/
      fi

      if [ -d "etc" ]; then
        cp -r etc $out/
      fi

      runHook postInstall
    '';

    meta = with lib; {
      description = "CrowdStrike Falcon Sensor for Linux";
      homepage = "https://falcon.crowdstrike.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  fs-bash = buildFHSEnv {
    name = "fs-bash";
    targetPkgs = pkgs: [
      libnl
      openssl
      zlib
    ];

    extraInstallCommands = ''ln -s ${falcon-sensor}/* $out/'';

    runScript = "bash";
  };
in
falcon-sensor.overrideAttrs (oldAttrs: {
  passthru = {
    fs-bash = fs-bash;
  };
})