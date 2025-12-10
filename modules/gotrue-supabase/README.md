# Supabase Auth (GoTrue) NixOS Module

This module runs the `auth` binary from `gotrue-supabase` and exposes configuration via environment variables (as per the upstream README).

## Usage

```nix
{
  imports = [ ./modules ]; # adjust path

  services.gotrue-supabase = {
    enable = true;

    # Required basics
    siteUrl = "https://example.netlify.com/";
    apiExternalUrl = "https://auth.example.com";
    databaseUrl = "postgresql://postgres:password@localhost:5432/postgres";
    jwtSecret = "supersecretvalue"; # better: keep in an env file

    # Override bind/logging if desired
    listenAddress = "0.0.0.0";
    apiPort = 8081;
    logLevel = "info";

    # Extra upstream settings (become GOTRUE_* env vars)
    settings = {
      GOTRUE_EXTERNAL_EMAIL_ENABLED = true;
      GOTRUE_SMTP_HOST = "smtp.example.com";
      GOTRUE_SMTP_PORT = 587;
      GOTRUE_SMTP_ADMIN_EMAIL = "support@example.com";
    };

    # Keep secrets out of the store
    environmentFiles = [ "/run/keys/gotrue.env" ];
  };
}
```

Example `/run/keys/gotrue.env` (only values you want secret):

```
GOTRUE_JWT_SECRET=supersecretvalue
DB_DATABASE_URL=postgresql://postgres:password@localhost:5432/postgres
```

Restart the service after changing values: `systemctl restart gotrue-supabase`. The module runs `auth serve` and applies database migrations on startup. Ensure Postgres is reachable first (the unit is ordered after `postgresql.service`).***
