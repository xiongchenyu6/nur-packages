{
  stdenv,
  lib,
  pkgs,
  dpkg,
  openssl,
  libnl,
  zlib,
  requireFile,
  autoPatchelfHook,
  buildFHSEnv,
  writeScript,
  ...
}:
let
  pname = "falcon-sensor";
  # Version information - update these when you have a new version
  version = "7.30.0";
  release = "18306";
  arch = "amd64";

  # SHA256 hash of the .deb file - users need to verify this matches their download
  debSha256 = "25faf5ae428ba0e0b67cf075401fd1310df57651424e2bfe742ff7b4711ba422";

  # Require users to manually download the .deb file from CrowdStrike
  # This avoids storing proprietary binaries in the repository
  src = requireFile {
    name = "falcon-sensor_${version}-${release}_${arch}.deb";
    sha256 = debSha256;
    message = ''
      This package requires the CrowdStrike Falcon Sensor .deb file.

      To use this package, you must:

      1. Download falcon-sensor_${version}-${release}_${arch}.deb from:
         https://falcon.crowdstrike.com/
         (You need a valid CrowdStrike account)

      2. Add the file to the Nix store using one of these methods:

         Option A: Use nix-store to add the file:
           nix-store --add-fixed sha256 falcon-sensor_${version}-${release}_${arch}.deb

         Option B: Use nix-prefetch-url:
           nix-prefetch-url --type sha256 file:///path/to/falcon-sensor_${version}-${release}_${arch}.deb

         Option C: Place the file in the Nix store manually:
           sudo cp falcon-sensor_${version}-${release}_${arch}.deb /nix/store/

      3. Verify the SHA256 hash matches: ${debSha256}

      4. Retry the build

      If you have a different version of the .deb file, you'll need to update
      the version, release, and debSha256 values in this package definition.
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
      # Extract the .deb file using dpkg-deb (same as AUR: tar -xf data.tar.xz)
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
      description = "CrowdStrike Falcon Sensor for Linux - Enterprise Endpoint Protection";
      longDescription = ''
        The CrowdStrike Falcon sensor is proprietary software for endpoint protection.
        By building and installing this package, you acknowledge that you are using
        software directly from CrowdStrike and agree to be bound by their End User
        License Agreement and Privacy Notice.

        Terms of Use: https://www.crowdstrike.com/software-terms-of-use/
        Privacy Notice: https://www.crowdstrike.com/privacy-notice/

        This package requires manual download of the .deb file from CrowdStrike.
      '';
      homepage = "https://falcon.crowdstrike.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = with maintainers; [ ];
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