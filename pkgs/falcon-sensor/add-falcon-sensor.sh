#!/usr/bin/env bash

# Helper script to add CrowdStrike Falcon Sensor .deb file to Nix store
# Usage: ./add-falcon-sensor.sh /path/to/falcon-sensor_*.deb

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/falcon-sensor_*.deb"
    echo ""
    echo "This script helps you add the CrowdStrike Falcon Sensor .deb file to the Nix store."
    echo ""
    echo "Steps:"
    echo "1. Download the .deb file from https://falcon.crowdstrike.com/"
    echo "2. Run this script with the path to the downloaded file"
    echo "3. The script will add it to the Nix store and verify the hash"
    exit 1
fi

DEB_FILE="$1"

if [ ! -f "$DEB_FILE" ]; then
    echo "Error: File not found: $DEB_FILE"
    exit 1
fi

# Expected values - update these if you have a different version
EXPECTED_VERSION="7.30.0"
EXPECTED_RELEASE="18306"
EXPECTED_ARCH="amd64"
EXPECTED_SHA256="25faf5ae428ba0e0b67cf075401fd1310df57651424e2bfe742ff7b4711ba422"
EXPECTED_FILENAME="falcon-sensor_${EXPECTED_VERSION}-${EXPECTED_RELEASE}_${EXPECTED_ARCH}.deb"

# Get the filename
FILENAME=$(basename "$DEB_FILE")

echo "Adding Falcon Sensor to Nix store..."
echo "File: $FILENAME"

# Add to Nix store
STORE_PATH=$(nix-store --add-fixed sha256 "$DEB_FILE")
echo "Added to Nix store: $STORE_PATH"

# Calculate SHA256
ACTUAL_SHA256=$(nix-hash --type sha256 --flat "$DEB_FILE")
echo "SHA256: $ACTUAL_SHA256"

# Check if it matches expected
if [ "$FILENAME" = "$EXPECTED_FILENAME" ]; then
    if [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ]; then
        echo ""
        echo "✓ Success! The file has been added to the Nix store."
        echo "✓ Version and hash match the expected values."
        echo ""
        echo "You can now build the falcon-sensor package:"
        echo "  nix build .#falcon-sensor --impure"
    else
        echo ""
        echo "⚠ Warning: SHA256 hash doesn't match!"
        echo "Expected: $EXPECTED_SHA256"
        echo "Got:      $ACTUAL_SHA256"
        echo ""
        echo "The file has been added to the Nix store, but you need to update"
        echo "the debSha256 value in package.nix to: $ACTUAL_SHA256"
    fi
else
    echo ""
    echo "⚠ Warning: Filename doesn't match expected version!"
    echo "Expected: $EXPECTED_FILENAME"
    echo "Got:      $FILENAME"
    echo ""
    echo "The file has been added to the Nix store, but you need to update"
    echo "the version, release, and debSha256 values in package.nix"
    echo ""
    echo "New SHA256: $ACTUAL_SHA256"
fi

echo ""
echo "Store path: $STORE_PATH"