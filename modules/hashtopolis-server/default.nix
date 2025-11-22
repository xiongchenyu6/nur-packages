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

  # Environment file for hashtopolis
  envFile = pkgs.writeText "hashtopolis.env" ''
    HASHTOPOLIS_ADMIN_USER=${cfg.adminUser}
    HASHTOPOLIS_ADMIN_PASSWORD=${cfg.adminPassword}
    MYSQL_HOST=${cfg.database.host}
    MYSQL_PORT=${toString cfg.database.port}
    MYSQL_DATABASE=${cfg.database.name}
    MYSQL_USER=${cfg.database.user}
    MYSQL_PASSWORD=${cfg.database.password}
    ${cfg.extraEnvVars}
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

    adminPassword = mkOption {
      type = types.str;
      default = "hashtopolis";
      description = "Initial admin password (should be changed after first login)";
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

      password = mkOption {
        type = types.str;
        description = "Database password";
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

    extraEnvVars = mkOption {
      type = types.lines;
      default = "";
      description = "Extra environment variables to pass to Hashtopolis";
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
      after = [ "network.target" ] ++ optional cfg.database.createLocally "mysql.service";
      requires = optional cfg.database.createLocally "mysql.service";

      environment = {
        HOME = cfg.dataDir;
        # Set environment variables that hashtopolis checks for directory paths
        HASHTOPOLIS_FILES_PATH = "${cfg.dataDir}/files";
        HASHTOPOLIS_IMPORT_PATH = "${cfg.dataDir}/import";
        HASHTOPOLIS_LOG_PATH = "${cfg.dataDir}/log";
        HASHTOPOLIS_CONFIG_PATH = "${cfg.dataDir}/config";
      };

      # preStart runs as root by default
      preStart = ''
        # StateDirectory ensures the directory exists, so we just need to manage contents

        # Check if this is a fresh install or if files need to be refreshed
        if [ ! -d "${cfg.dataDir}/src" ]; then
          echo "First time setup - installing Hashtopolis files..."

          # Clean contents if directory exists but no src folder
          if [ -d "${cfg.dataDir}" ]; then
            echo "Cleaning existing contents..."
            # Fix permissions on existing contents to allow deletion
            find ${cfg.dataDir} -type d -exec chmod 755 {} \; 2>/dev/null || true
            find ${cfg.dataDir} -type f -exec chmod 644 {} \; 2>/dev/null || true
            # Remove all contents but not the directory itself
            rm -rf ${cfg.dataDir}/* ${cfg.dataDir}/.[!.]* 2>/dev/null || true
          fi

          # Copy all files from the package
          cp -r ${cfg.package}/share/hashtopolis/* ${cfg.dataDir}/

          # Fix ownership and permissions
          chown -R hashtopolis:hashtopolis ${cfg.dataDir}
          find ${cfg.dataDir} -type d -exec chmod 755 {} \;
          find ${cfg.dataDir} -type f -exec chmod 644 {} \;
        else
          # Existing installation - just ensure permissions are correct
          echo "Hashtopolis files already present in ${cfg.dataDir}"

          # Fix any permission issues
          chown -R hashtopolis:hashtopolis ${cfg.dataDir}
          find ${cfg.dataDir} -type d -exec chmod 755 {} \;
          find ${cfg.dataDir} -type f -exec chmod 644 {} \;
        fi

        # Create required directories for Hashtopolis operation
        mkdir -p ${cfg.dataDir}/files
        mkdir -p ${cfg.dataDir}/import
        mkdir -p ${cfg.dataDir}/log
        mkdir -p ${cfg.dataDir}/tmp
        mkdir -p ${cfg.dataDir}/config

        # Ensure proper ownership and permissions on runtime directories
        chown -R hashtopolis:hashtopolis ${cfg.dataDir}/files ${cfg.dataDir}/import ${cfg.dataDir}/log ${cfg.dataDir}/tmp ${cfg.dataDir}/config
        chmod -R 755 ${cfg.dataDir}/files ${cfg.dataDir}/import ${cfg.dataDir}/log ${cfg.dataDir}/tmp ${cfg.dataDir}/config

        # Setup environment file (always refresh this)
        cp -f ${envFile} ${cfg.dataDir}/.env
        chown hashtopolis:hashtopolis ${cfg.dataDir}/.env
        chmod 600 ${cfg.dataDir}/.env
      '';

      serviceConfig = {
        Type = "simple";
        User = "hashtopolis";
        Group = "hashtopolis";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.phpPackage}/bin/php -S ${cfg.listenAddress}:${toString cfg.port} -t ${cfg.dataDir}/src";
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
        # ReadWritePaths is not needed when using StateDirectory
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