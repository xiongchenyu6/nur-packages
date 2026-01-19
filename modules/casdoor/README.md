# Casdoor Module

This module provides a NixOS module for deploying [Casdoor](https://casdoor.org/), an identity and access management (IAM) platform.

## Basic Usage

```nix
{ config, pkgs, ... }:

{
  services.casdoor = {
    enable = true;
    database = {
      host = "localhost";
      port = 5432;
      username = "casdoor";
      password = "secret";
      name = "casdoor";
    };
  };
}
```

## Configuration

All configuration options are documented in the module source.

## Database Setup

Before enabling casdoor, you need to create the database. For PostgreSQL:

```sql
CREATE USER casdoor WITH PASSWORD 'secret';
CREATE DATABASE casdoor OWNER casdoor;
GRANT ALL PRIVILEGES ON DATABASE casdoor TO casdoor;
```

## Reverse Proxy

For production deployments, you typically run casdoor behind a reverse proxy:

```nix
services.nginx = {
  enable = true;
  virtualHosts = {
    "auth.example.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
      };
    };
  };
};
```
