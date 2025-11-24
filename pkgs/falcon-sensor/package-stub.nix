# Stub/placeholder package for falcon-sensor
# This allows the repository to build without the proprietary .deb file
{ stdenv, lib, writeShellScriptBin }:

let
  pname = "falcon-sensor";
  version = "7.30.0";
in
stdenv.mkDerivation {
  inherit pname version;

  src = null;
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin

    # Create a placeholder script that shows instructions
    cat > $out/bin/falcon-sensor-placeholder << 'EOF'
    #!/bin/sh
    echo "========================================="
    echo "CrowdStrike Falcon Sensor - Not Installed"
    echo "========================================="
    echo ""
    echo "This is a placeholder package. To use the actual Falcon Sensor:"
    echo ""
    echo "1. Download the .deb file from https://falcon.crowdstrike.com/"
    echo "2. Use the add-falcon-sensor.sh script in pkgs/falcon-sensor/"
    echo "3. Rebuild with the actual package.nix"
    echo ""
    echo "See pkgs/falcon-sensor/README.md for detailed instructions."
    EOF

    chmod +x $out/bin/falcon-sensor-placeholder

    # Create a dummy falconctl for the module to not fail
    cat > $out/bin/falconctl << 'EOF'
    #!/bin/sh
    echo "falconctl: This is a placeholder. Install the real falcon-sensor package."
    exit 1
    EOF
    chmod +x $out/bin/falconctl
  '';

  meta = with lib; {
    description = "CrowdStrike Falcon Sensor (Placeholder - requires manual .deb download)";
    longDescription = ''
      This is a placeholder package for CrowdStrike Falcon Sensor.

      The actual sensor requires downloading a proprietary .deb file from CrowdStrike.
      This placeholder allows the NUR repository to build without the proprietary file.

      To install the actual sensor, follow the instructions in pkgs/falcon-sensor/README.md
    '';
    homepage = "https://falcon.crowdstrike.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}