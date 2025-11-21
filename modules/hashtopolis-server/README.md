# Hashtopolis Server NixOS Module

This module provides a NixOS service configuration for running Hashtopolis server, a multi-platform client-server tool for distributing hashcat tasks.

## Usage Example

### Basic Setup

```nix
{
  services.hashtopolis-server = {
    enable = true;

    # Database configuration
    database = {
      password = "secure-password-here"; # Change this!
      createLocally = true; # Automatically creates MariaDB database
    };

    # Admin credentials (change after first login)
    adminUser = "admin";
    adminPassword = "secure-admin-password";

    # Listen configuration
    listenAddress = "0.0.0.0"; # Listen on all interfaces
    port = 8080;
  };
}
```

### With Nginx Reverse Proxy

```nix
{
  services.hashtopolis-server = {
    enable = true;

    database = {
      password = "secure-password-here";
      createLocally = true;
    };

    # Keep internal only when using nginx
    listenAddress = "127.0.0.1";
    port = 8080;

    # Enable nginx reverse proxy
    nginx = {
      enable = true;
      virtualHost = "hashtopolis.example.com";
    };
  };

  # SSL configuration for nginx
  services.nginx.virtualHosts."hashtopolis.example.com" = {
    enableACME = true;
    forceSSL = true;
  };
}
```

### Using External Database

```nix
{
  services.hashtopolis-server = {
    enable = true;

    database = {
      host = "db.example.com";
      port = 3306;
      name = "hashtopolis";
      user = "hashtopolis";
      password = "secure-password";
      createLocally = false; # Don't create local database
    };

    listenAddress = "0.0.0.0";
    port = 8080;
  };
}
```

### Custom PHP Configuration

```nix
{
  services.hashtopolis-server = {
    enable = true;

    database = {
      password = "secure-password";
      createLocally = true;
    };

    # Use custom PHP package with additional extensions
    phpPackage = pkgs.php82.withExtensions ({ enabled, all }:
      enabled ++ (with all; [
        imagick
        redis
      ])
    );

    # Additional environment variables
    extraEnvVars = ''
      HASHTOPOLIS_DEBUG=1
      HASHTOPOLIS_MAX_UPLOAD_SIZE=500M
    '';
  };
}
```

## Options

### `services.hashtopolis-server.enable`
Enable the Hashtopolis server service.

### `services.hashtopolis-server.package`
The Hashtopolis server package to use. Default: `pkgs.hashtopolis-server`

### `services.hashtopolis-server.listenAddress`
IP address to bind to. Default: `"127.0.0.1"`

### `services.hashtopolis-server.port`
Port to listen on. Default: `8080`

### `services.hashtopolis-server.dataDir`
Directory for Hashtopolis data storage. Default: `"/var/lib/hashtopolis"`

### `services.hashtopolis-server.adminUser`
Initial admin username. Default: `"admin"`

### `services.hashtopolis-server.adminPassword`
Initial admin password (should be changed after first login). Default: `"hashtopolis"`

### Database Options

- `database.host`: Database server hostname (default: `"localhost"`)
- `database.port`: Database server port (default: `3306`)
- `database.name`: Database name (default: `"hashtopolis"`)
- `database.user`: Database username (default: `"hashtopolis"`)
- `database.password`: Database password (required)
- `database.createLocally`: Whether to create database locally (default: `true`)

### Nginx Options

- `nginx.enable`: Enable nginx reverse proxy (default: `false`)
- `nginx.virtualHost`: Virtual host name for nginx (default: `"hashtopolis.local"`)

### Other Options

- `phpPackage`: PHP package with required extensions
- `extraEnvVars`: Additional environment variables

## Security Considerations

1. **Change default passwords**: Always change the default admin password and database password
2. **Use HTTPS**: Enable nginx with SSL/TLS for production deployments
3. **Firewall**: The service opens the configured port in the firewall when nginx is not enabled
4. **Database security**: Use strong passwords and consider network isolation for the database

## Post-Installation Steps

1. Access the web interface at `http://your-server:8080` (or your configured address)
2. Login with the configured admin credentials
3. Change the admin password immediately
4. Create agent vouchers for connecting agents
5. Configure task templates and wordlists as needed

## Troubleshooting

### Check service status
```bash
systemctl status hashtopolis-server
```

### View logs
```bash
journalctl -u hashtopolis-server -f
```

### Restart service
```bash
systemctl restart hashtopolis-server
```

### Database connection issues
- Ensure MariaDB/MySQL is running: `systemctl status mysql`
- Check database credentials are correct
- Verify network connectivity to database host

## Related

See also the [Hashtopolis Agent module](../hashtopolis-agent/README.md) for setting up distributed agents.