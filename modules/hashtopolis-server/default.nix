{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hashtopolis-server;

  hashtopolisServerPkg = pkgs.callPackage ../../pkgs/hashtopolis-server/package.nix { };

  # PHP with required extensions
  php = pkgs.php82.withExtensions ({ enabled, all }: enabled ++ (with all; [
    mysqli
    pdo_mysql
    curl
    gd
    mbstring
    zip
    openssl
    session
  ]));

  # Build PHP -d flags from phpOptions
  phpFlags = concatStringsSep " " (mapAttrsToList (k: v: "-d ${k}=${v}") cfg.phpOptions);

  # preStart script that generates .env at runtime from non-secret options + secret files
  preStartScript = pkgs.writeShellScript "hashtopolis-pre-start" ''
    set -euo pipefail

    ENV_FILE="${cfg.dataDir}/.env"

    # Write non-secret values
    cat > "$ENV_FILE" <<'ENVEOF'
HASHTOPOLIS_ADMIN_USER=${cfg.adminUser}
HASHTOPOLIS_DB_HOST=${cfg.database.host}
HASHTOPOLIS_DB_USER=${cfg.database.user}
HASHTOPOLIS_DB_DATABASE=${cfg.database.name}
MYSQL_HOST=${cfg.database.host}
MYSQL_PORT=${toString cfg.database.port}
MYSQL_DATABASE=${cfg.database.name}
MYSQL_USER=${cfg.database.user}
${cfg.extraEnvVars}
ENVEOF

    # Append secrets read from files
    ${optionalString (cfg.adminPasswordFile != null) ''
      printf 'HASHTOPOLIS_ADMIN_PASSWORD=%s\n' "$(cat ${cfg.adminPasswordFile})" >> "$ENV_FILE"
    ''}
    ${optionalString (cfg.database.passwordFile != null) ''
      DB_PASS="$(cat ${cfg.database.passwordFile})"
      printf 'HASHTOPOLIS_DB_PASS=%s\n' "$DB_PASS" >> "$ENV_FILE"
      printf 'MYSQL_PASSWORD=%s\n' "$DB_PASS" >> "$ENV_FILE"
    ''}

    # If an environmentFile is provided, append its contents (overrides above)
    ${optionalString (cfg.environmentFile != null) ''
      if [ -f "${cfg.environmentFile}" ]; then
        cat "${cfg.environmentFile}" >> "$ENV_FILE"
      fi
    ''}

    chown hashtopolis:hashtopolis "$ENV_FILE"
    chmod 600 "$ENV_FILE"
  '';

in {
  options.services.hashtopolis-server = {
    enable = mkEnableOption "Hashtopolis server - distributed hashcat task management";

    package = mkOption {
      type = types.package;
      default = hashtopolisServerPkg;
      description = "Hashtopolis server package to use";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address on which the Hashtopolis server will listen";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port on which the Hashtopolis server will listen";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/hashtopolis";
      description = "Directory where Hashtopolis stores its data";
    };

    adminUser = mkOption {
      type = types.str;
      default = "admin";
      description = "Initial admin username";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/hashtopolis-admin-password";
      description = "Path to file containing the initial admin password";
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "MySQL/MariaDB database host";
      };

      port = mkOption {
        type = types.port;
        default = 3306;
        description = "MySQL/MariaDB database port";
      };

      name = mkOption {
        type = types.str;
        default = "hashtopolis";
        description = "Database name";
      };

      user = mkOption {
        type = types.str;
        default = "hashtopolis";
        description = "Database user";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/hashtopolis-db-password";
        description = "Path to file containing the database password";
      };

      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create the database locally";
      };
    };

    phpPackage = mkOption {
      type = types.package;
      default = php;
      description = "PHP package to use (with required extensions)";
    };

    phpOptions = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = { memory_limit = "1024M"; };
      description = "PHP ini directives passed via -d flags to the PHP built-in server";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/hashtopolis.env";
      description = "Path to environment file with additional secrets. Variables here are appended to the generated .env file.";
    };

    extraEnvVars = mkOption {
      type = types.lines;
      default = "";
      description = "Extra environment variable lines to include in the generated .env file";
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable nginx as a reverse proxy for Hashtopolis";
      };

      virtualHost = mkOption {
        type = types.str;
        default = "hashtopolis.local";
        description = "Virtual host name for nginx";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.hashtopolis = {
      isSystemUser = true;
      group = "hashtopolis";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.hashtopolis = {};

    # Create required subdirectories via tmpfiles
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/files 0755 hashtopolis hashtopolis -"
      "d ${cfg.dataDir}/import 0755 hashtopolis hashtopolis -"
      "d ${cfg.dataDir}/log 0755 hashtopolis hashtopolis -"
      "d ${cfg.dataDir}/tmp 0755 hashtopolis hashtopolis -"
      "d ${cfg.dataDir}/config 0755 hashtopolis hashtopolis -"
      "d ${cfg.dataDir}/locks 0755 hashtopolis hashtopolis -"
    ];

    # Create database if requested
    services.mysql = mkIf cfg.database.createLocally {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = {
            "${cfg.database.name}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # Setup systemd service
    systemd.services.hashtopolis-server = {
      description = "Hashtopolis Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "systemd-tmpfiles-setup.service" ]
        ++ optional cfg.database.createLocally "mysql.service";
      requires = optional cfg.database.createLocally "mysql.service";

      environment = {
        HOME = cfg.dataDir;
        HASHTOPOLIS_FILES_PATH = "${cfg.dataDir}/files";
        HASHTOPOLIS_IMPORT_PATH = "${cfg.dataDir}/import";
        HASHTOPOLIS_LOG_PATH = "${cfg.dataDir}/log";
        HASHTOPOLIS_CONFIG_PATH = "${cfg.dataDir}/config";
        HASHTOPOLIS_LOCKS_PATH = "${cfg.dataDir}/locks";
      };

      serviceConfig = {
        Type = "simple";
        User = "hashtopolis";
        Group = "hashtopolis";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = "+${preStartScript}";
        EnvironmentFile = "${cfg.dataDir}/.env";
        ExecStart = "${cfg.phpPackage}/bin/php ${phpFlags} -S ${cfg.listenAddress}:${toString cfg.port} -t ${cfg.package}/share/hashtopolis/src";
        Restart = "always";
        RestartSec = "10s";

        # Directory management
        StateDirectory = "hashtopolis";
        StateDirectoryMode = "0755";

        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Configure nginx if enabled
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts.${cfg.nginx.virtualHost} = {
        locations."/" = {
          proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Increase timeouts for long-running operations
            proxy_connect_timeout 600;
            proxy_send_timeout 600;
            proxy_read_timeout 600;
            send_timeout 600;

            # Increase body size for file uploads
            client_max_body_size 100M;
          '';
        };
      };
    };

    # Open firewall if nginx is not enabled (direct access)
    networking.firewall = mkIf (!cfg.nginx.enable) {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
