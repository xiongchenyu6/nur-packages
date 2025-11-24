# CrowdStrike Falcon Sensor for NixOS

This package provides the CrowdStrike Falcon Sensor for Linux systems running NixOS. Since the sensor requires downloading a proprietary .deb file from CrowdStrike's portal (authentication required), we provide multiple installation methods.

## Why Can't Nix Auto-Download This?

Unlike most packages, the Falcon Sensor cannot be automatically downloaded because:
- **No Public URL**: CrowdStrike requires login to their portal
- **Authentication Required**: Downloads need valid CrowdStrike credentials
- **License Restrictions**: Proprietary software requiring EULA acceptance
- **Nix Purity**: Authenticated downloads would break reproducible builds

## Installation Methods

### Method 1: Build with Stub (Testing/Development)

Use this to test your NUR builds without the actual sensor:

```bash
# Build with stub package (for testing)
FALCON_SENSOR_STUB=1 nix build .#falcon-sensor --impure
```

This creates a placeholder package that won't fail your builds but provides instructions instead of the actual sensor.

### Method 2: Provide Your Own Download URL

If you have the .deb file hosted somewhere (private S3, internal server, etc.):

```bash
# Build with your URL
export FALCON_SENSOR_URL="https://your-server.com/falcon-sensor_7.30.0-18306_amd64.deb"
nix build .#falcon-sensor --impure

# Or try with local file
export FALCON_SENSOR_URL="file:///path/to/falcon-sensor_7.30.0-18306_amd64.deb"
nix build .#falcon-sensor --impure
```

### Method 3: Manual Download (Most Common)

#### Step 1: Download the .deb file

1. Log in to your CrowdStrike Falcon console at https://falcon.crowdstrike.com/
2. Navigate to the sensor downloads section
3. Download the Linux sensor for Debian/Ubuntu (amd64)
   - Current version: `falcon-sensor_7.30.0-18306_amd64.deb`
   - SHA256: `25faf5ae428ba0e0b67cf075401fd1310df57651424e2bfe742ff7b4711ba422`

#### Step 2: Add to Nix Store

Use the helper script (recommended):
```bash
cd pkgs/falcon-sensor
./add-falcon-sensor.sh /path/to/falcon-sensor_7.30.0-18306_amd64.deb
```

Or manually:
```bash
# Using nix-store
nix-store --add-fixed sha256 falcon-sensor_7.30.0-18306_amd64.deb

# Or using nix-prefetch-url
nix-prefetch-url --type sha256 file:///path/to/falcon-sensor_7.30.0-18306_amd64.deb
```

#### Step 3: Build the Package

```bash
# Allow unfree packages
export NIXPKGS_ALLOW_UNFREE=1

# Build the package
nix build .#falcon-sensor --impure
```

## NixOS Module Configuration

Once installed, configure the sensor in your NixOS configuration:

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

### Manual Provisioning (Alternative)

If you prefer to manually provision with a provisioning token:

```bash
# Configure with your CID and provisioning token
sudo /opt/CrowdStrike/falconctl -s -f --cid=<YOUR_CID> --provisioning-token=<YOUR_TOKEN>

# Restart the service
sudo systemctl restart falcon-sensor
```

## Environment Variables

The package respects these environment variables during build:

| Variable | Value | Description |
|----------|-------|-------------|
| `FALCON_SENSOR_STUB` | `1` | Build stub package for testing |
| `FALCON_SENSOR_URL` | URL | Download from specified URL |
| `FALCON_SENSOR_DOWNLOAD` | `1` | Try downloading from predefined URLs |

## Updating to New Versions

When CrowdStrike releases a new version:

1. Update version information in these files:
   - `package.nix`
   - `package-with-url.nix`
   - `package-stub.nix`

   ```nix
   version = "7.31.0";  # New version
   release = "18400";   # New release
   debSha256 = "new-sha256-hash";  # New hash
   ```

2. Calculate the SHA256 hash of the new .deb:
   ```bash
   sha256sum falcon-sensor_*.deb
   ```

3. Update `add-falcon-sensor.sh` with the new hash

4. Follow the installation steps with the new file

## Troubleshooting

### "This package requires the CrowdStrike Falcon Sensor .deb file"

The .deb file isn't in your Nix store. Use one of the installation methods above.

### SHA256 Mismatch

If you get a hash mismatch error:
- Verify you downloaded the correct version (7.30.0-18306)
- Check the file isn't corrupted
- Update the SHA256 if using a different version

### Build Fails with Network Error

When using Method 2 with URL:
- Ensure the URL is accessible
- Check if authentication is required
- Try downloading manually first to verify

### Service Fails to Start

Check the systemd logs:
```bash
journalctl -u falcon-sensor -f
```

Ensure your CID file is properly configured and readable.

## fs-bash FHS Environment

The package includes an FHS environment for testing:

```bash
# Enter FHS environment with Falcon Sensor
nix run .#falcon-sensor.fs-bash
```

## Security & Legal Notice

This package follows the same approach as the AUR (Arch User Repository) package, requiring manual download of the proprietary binary. This ensures:
- No proprietary code is stored in the repository
- Users explicitly consent to downloading and using the software
- The package respects CrowdStrike's distribution terms

By using this package, you acknowledge that you are using software directly from CrowdStrike and agree to their:
- [Terms of Use](https://www.crowdstrike.com/terms-conditions/)
- [Privacy Notice](https://www.crowdstrike.com/privacy-notice/)

## Support

- **Nix packaging issues**: Open an issue in this repository
- **Falcon Sensor issues**: Contact CrowdStrike support