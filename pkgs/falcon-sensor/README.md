# CrowdStrike Falcon Sensor for NixOS

This package provides the CrowdStrike Falcon Sensor for Linux systems running NixOS.

## Important Note

The Falcon Sensor .deb file is proprietary software and cannot be distributed in this repository. You must download it manually from CrowdStrike.

## Installation

### Step 1: Download the .deb file

1. Log in to your CrowdStrike Falcon console at https://falcon.crowdstrike.com/
2. Navigate to the sensor downloads section
3. Download the Linux sensor for Debian/Ubuntu (amd64)
   - Current version in this package: `falcon-sensor_7.30.0-18306_amd64.deb`
   - SHA256: `25faf5ae428ba0e0b67cf075401fd1310df57651424e2bfe742ff7b4711ba422`

### Step 2: Add the file to the Nix store

Choose one of these methods:

#### Method A: Using the helper script (Recommended)
```bash
# From the falcon-sensor package directory
./add-falcon-sensor.sh /path/to/falcon-sensor_7.30.0-18306_amd64.deb
```

#### Method B: Using nix-store
```bash
nix-store --add-fixed sha256 falcon-sensor_7.30.0-18306_amd64.deb
```

#### Method C: Using nix-prefetch-url
```bash
nix-prefetch-url --type sha256 file:///path/to/falcon-sensor_7.30.0-18306_amd64.deb
```

### Step 3: Build the package

```bash
# Allow unfree packages (Falcon Sensor is proprietary)
export NIXPKGS_ALLOW_UNFREE=1

# Build the package
nix build .#falcon-sensor --impure
```

### Step 4: Configure in NixOS

Add to your NixOS configuration:

```nix
{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the Falcon Sensor service
  services.falcon-sensor = {
    enable = true;
    cidFile = "/run/secrets/falcon-cid"; # Path to your CID file
  };
}
```

### Step 5: Alternative Manual Provisioning

If you prefer to manually provision with a provisioning token instead of using a CID file:

```bash
# Configure with your CID and provisioning token
sudo /opt/CrowdStrike/falconctl -s -f --cid=<YOUR_CID> --provisioning-token=<YOUR_TOKEN>

# Restart the service
sudo systemctl restart falcon-sensor
```

Note: You can get your CID and provisioning token from the Falcon console under "Host setup and management".

## Updating the Package

When CrowdStrike releases a new version:

1. Update the version information in `package.nix`:
   - `version`: The version number (e.g., "7.30.0")
   - `release`: The release number (e.g., "18306")
   - `debSha256`: The SHA256 hash of the new .deb file

2. Calculate the SHA256 hash of the new .deb file:
   ```bash
   sha256sum falcon-sensor_*.deb
   ```

3. Follow the installation steps above with the new file

## Troubleshooting

### "file not found" error
Make sure you've added the .deb file to the Nix store using one of the methods above.

### "hash mismatch" error
The SHA256 hash of your .deb file doesn't match the expected hash. Either:
- You have a different version - update the package definition
- The file is corrupted - download it again

### Service fails to start
Check the systemd logs:
```bash
journalctl -u falcon-sensor -f
```

Ensure your CID file is properly configured and readable.

## Security Note

This package follows the same approach as the AUR (Arch User Repository) package, requiring manual download of the proprietary binary. This ensures:
- No proprietary code is stored in the repository
- Users explicitly consent to downloading and using the software
- The package respects CrowdStrike's distribution terms