# Hashtopolis Agent NixOS Module

This module provides a NixOS service configuration for running Hashtopolis agents, which connect to a Hashtopolis server to perform distributed hashcat tasks.

## Usage Examples

### Basic Agent Setup

```nix
{
  services.hashtopolis-agent = {
    enable = true;

    # Server connection
    serverUrl = "http://hashtopolis.example.com:8080/api/server.php";

    # Registration voucher (get from server UI)
    voucher = "VOUCHER_FROM_SERVER";

    # Use system hashcat
    useNativeHashcat = true;
    hashcatPackage = pkgs.hashcat;
  };
}
```

### CPU-Only Agent

```nix
{
  services.hashtopolis-agent = {
    enable = true;

    serverUrl = "http://hashtopolis.example.com:8080/api/server.php";
    voucher = "VOUCHER_FROM_SERVER";

    # Force CPU-only mode
    cpuOnly = true;
    deviceTypes = [ "cpu" ];

    # Limit resource usage
    cpuQuota = 75; # Use max 75% CPU
    memoryLimit = "4G";
  };
}
```

### GPU-Enabled Agent

```nix
{
  services.hashtopolis-agent = {
    enable = true;

    serverUrl = "http://hashtopolis.example.com:8080/api/server.php";
    voucher = "VOUCHER_FROM_SERVER";

    # Enable GPU support
    deviceTypes = [ "gpu" "cpu" ];

    # Use specific GPUs (empty means all)
    gpuDevices = [ 0 1 ]; # Use GPU 0 and 1

    # Install hashcat with CUDA support
    useNativeHashcat = true;
    hashcatPackage = pkgs.hashcat; # Ensure this has CUDA support
  };

  # Ensure GPU drivers are available
  hardware.graphics.enable = true;
}
```

### Multiple Agents on Same Machine

```nix
{
  # First agent - GPU 0
  services.hashtopolis-agent = {
    enable = true;
    serverUrl = "http://hashtopolis.example.com:8080/api/server.php";
    voucher = "VOUCHER_1";
    dataDir = "/var/lib/hashtopolis-agent-1";
    gpuDevices = [ 0 ];
  };

  # Second agent - GPU 1 (requires manual service file creation)
  systemd.services.hashtopolis-agent-2 = {
    description = "Hashtopolis Agent 2";
    wantedBy = [ "multi-user.target" ];
    # ... configure second instance
  };
}
```

### Agent with Custom Configuration

```nix
{
  services.hashtopolis-agent = {
    enable = true;

    serverUrl = "http://hashtopolis.example.com:8080/api/server.php";
    voucher = "VOUCHER_FROM_SERVER";

    # Custom paths
    dataDir = "/data/hashtopolis-agent";
    crackersPath = "/data/hashtopolis/crackers";

    # Allow piping mode
    allowPiping = true;

    # Custom user (must have GPU access if using GPU)
    user = "hashcat";
    group = "hashcat";

    # Don't auto-start (manual control)
    autoStart = false;

    # Custom environment
    environmentFile = "/etc/hashtopolis-agent.env";
  };
}
```

## Options

### Connection Options

- `serverUrl`: URL of the Hashtopolis server API endpoint (required)
- `voucher`: Registration voucher from server (required for initial registration)
- `uuid`: Agent UUID (automatically set after registration)

### Directory Options

- `dataDir`: Agent data directory (default: `"/var/lib/hashtopolis-agent"`)
- `crackersPath`: Directory for hashcat/crackers (default: `"${dataDir}/crackers"`)
- `princePath`: Directory for PRINCE preprocessor (default: `"${dataDir}/prince"`)
- `preprocessorsPath`: Directory for preprocessors (default: `"${dataDir}/preprocessors"`)

### Hashcat Options

- `useNativeHashcat`: Use system hashcat instead of downloading (default: `false`)
- `hashcatPackage`: Hashcat package to use when `useNativeHashcat` is true
- `allowPiping`: Enable piping mode for hashcat (default: `false`)

### Device Options

- `deviceTypes`: List of device types to use: `["cpu"]`, `["gpu"]`, or both (default: `["cpu"]`)
- `gpuDevices`: Specific GPU device IDs to use (empty = all available)
- `cpuOnly`: Force CPU-only mode even if GPUs available (default: `false`)

### Resource Limits

- `memoryLimit`: Memory limit for agent process (e.g., `"4G"`)
- `cpuQuota`: CPU usage percentage limit (1-100)

### Service Options

- `user`: User to run agent as (default: `"hashtopolis-agent"`)
- `group`: Group for agent user (default: `"hashtopolis-agent"`)
- `autoStart`: Start agent automatically on boot (default: `true`)
- `restartOnFailure`: Restart agent on failure (default: `true`)
- `environmentFile`: Path to additional environment variables file

## Agent Registration Process

1. **Get a voucher from the server**:
   - Login to Hashtopolis server web interface
   - Go to Agents → New Agent
   - Create a voucher and copy it

2. **Configure the agent with the voucher**:
   ```nix
   services.hashtopolis-agent.voucher = "YOUR_VOUCHER_HERE";
   ```

3. **Start the agent**:
   ```bash
   systemctl start hashtopolis-agent
   ```

4. **Verify registration**:
   - Check the server UI - the agent should appear
   - The agent will save its UUID for future connections

5. **Remove the voucher** (optional):
   - After successful registration, the voucher is no longer needed
   - The agent uses its UUID for authentication

## GPU Setup

For GPU-accelerated cracking:

1. **Install GPU drivers**:
   ```nix
   hardware.graphics.enable = true;
   # For NVIDIA:
   services.xserver.videoDrivers = [ "nvidia" ];
   # Or for AMD:
   hardware.graphics.extraPackages = [ pkgs.rocm-opencl-icd ];
   ```

2. **Ensure hashcat has GPU support**:
   ```nix
   services.hashtopolis-agent.hashcatPackage = pkgs.hashcat; # Should include CUDA/OpenCL
   ```

3. **Configure agent for GPU**:
   ```nix
   services.hashtopolis-agent.deviceTypes = [ "gpu" ];
   ```

## Monitoring and Troubleshooting

### Check agent status
```bash
systemctl status hashtopolis-agent
```

### View agent logs
```bash
journalctl -u hashtopolis-agent -f
```

### Restart agent
```bash
systemctl restart hashtopolis-agent
```

### Common Issues

**Agent won't register**:
- Verify server URL is correct and accessible
- Check voucher is valid and unused
- Ensure network connectivity to server

**GPU not detected**:
- Check GPU drivers are installed
- Verify user has access to GPU devices
- Check `nvidia-smi` or `rocm-smi` output

**High resource usage**:
- Set `cpuQuota` and `memoryLimit` options
- Use `cpuOnly` mode if GPU not needed
- Limit to specific GPU devices

**Agent keeps restarting**:
- Check logs for error messages
- Verify server is accessible
- Ensure data directory has correct permissions

## Security Considerations

1. **Network Security**: Use HTTPS for server connections in production
2. **Voucher Management**: Keep vouchers secure and remove after registration
3. **Resource Limits**: Set appropriate limits to prevent system overload
4. **User Permissions**: Run as non-root user with minimal required permissions
5. **GPU Access**: Only grant GPU access if actually needed

## Related

See also the [Hashtopolis Server module](../hashtopolis-server/README.md) for setting up the server.