{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.dify;

  # Environment variables shared by all Dify services
  difyEnv = {
    # Deployment
    DEPLOY_ENV = "PRODUCTION";
    EDITION = "SELF_HOSTED";
    LOG_LEVEL = cfg.api.logLevel;

    # Database
    DB_TYPE = "postgresql";
    DB_HOST = cfg.database.host;
    DB_PORT = toString cfg.database.port;
    DB_USERNAME = cfg.database.user;
    DB_DATABASE = cfg.database.name;

    # Redis
    REDIS_HOST = cfg.redis.host;
    REDIS_PORT = toString cfg.redis.port;
    REDIS_USE_SSL = "false";
    REDIS_DB = "0";
    CELERY_BROKER_URL = "redis://${cfg.redis.host}:${toString cfg.redis.port}/1";

    # Storage
    STORAGE_TYPE = cfg.storage.type;
    STORAGE_LOCAL_PATH = cfg.storage.localPath;

    # Migration
    MIGRATION_ENABLED = boolToString cfg.api.migrationEnabled;

    # Web URLs (for CORS and redirects)
    CONSOLE_API_URL = cfg.api.consoleApiUrl;
    CONSOLE_WEB_URL = cfg.web.consoleWebUrl;
    SERVICE_API_URL = cfg.api.serviceApiUrl;
    APP_API_URL = cfg.api.appApiUrl;
    FILES_URL = cfg.api.filesUrl;
  };
in
{
  options.services.dify = {
    enable = mkEnableOption "Dify - open-source LLM application platform";

    package = {
      api = mkOption {
        type = types.package;
        default = pkgs.dify-api;
        description = "Dify API package to use";
      };

      web = mkOption {
        type = types.package;
        default = pkgs.dify-web;
        description = "Dify web frontend package to use";
      };
    };

    user = mkOption {
      type = types.str;
      default = "dify";
      description = "User under which Dify runs";
    };

    group = mkOption {
      type = types.str;
      default = "dify";
      description = "Group under which Dify runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/dify";
      description = "Data directory for Dify";
    };

    secretKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the SECRET_KEY. Must be set for production use.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file with additional secrets (API keys, etc.)";
    };

    api = {
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address the API server binds to";
      };

      port = mkOption {
        type = types.port;
        default = 5001;
        description = "Port the API server listens on";
      };

      workers = mkOption {
        type = types.int;
        default = 1;
        description = "Number of gunicorn workers";
      };

      workerClass = mkOption {
        type = types.str;
        default = "gevent";
        description = "Gunicorn worker class";
      };

      logLevel = mkOption {
        type = types.enum [
          "DEBUG"
          "INFO"
          "WARNING"
          "ERROR"
        ];
        default = "INFO";
        description = "Log level for the API server";
      };

      migrationEnabled = mkOption {
        type = types.bool;
        default = true;
        description = "Run database migrations on startup";
      };

      consoleApiUrl = mkOption {
        type = types.str;
        default = "";
        description = "Console API URL for CORS";
      };

      serviceApiUrl = mkOption {
        type = types.str;
        default = "";
        description = "Service API URL";
      };

      appApiUrl = mkOption {
        type = types.str;
        default = "";
        description = "App API URL";
      };

      filesUrl = mkOption {
        type = types.str;
        default = "";
        description = "Files download URL";
      };
    };

    web = {
      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port the web frontend listens on";
      };

      consoleWebUrl = mkOption {
        type = types.str;
        default = "";
        description = "Console web URL";
      };
    };

    worker = {
      concurrency = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Celery worker concurrency (null for auto)";
      };

      queues = mkOption {
        type = types.str;
        default = "dataset,generation,mail,ops_trace,plugin";
        description = "Comma-separated list of Celery queues to process";
      };
    };

    database = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Create PostgreSQL database automatically";
      };

      host = mkOption {
        type = types.str;
        default = "/run/postgresql";
        description = "Database host (use socket path for local)";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "Database port";
      };

      name = mkOption {
        type = types.str;
        default = "dify";
        description = "Database name";
      };

      user = mkOption {
        type = types.str;
        default = "dify";
        description = "Database user";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing database password";
      };

      enablePgvector = mkOption {
        type = types.bool;
        default = true;
        description = "Install and enable pgvector extension";
      };
    };

    redis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Create Redis instance automatically";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Redis host";
      };

      port = mkOption {
        type = types.port;
        default = 6379;
        description = "Redis port";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing Redis password";
      };
    };

    storage = {
      type = mkOption {
        type = types.enum [
          "local"
          "opendal"
          "s3"
          "azure-blob"
          "google-storage"
        ];
        default = "local";
        description = "Storage backend type";
      };

      localPath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/storage";
        description = "Local storage path";
      };
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable nginx reverse proxy for Dify";
      };

      domain = mkOption {
        type = types.str;
        default = "localhost";
        description = "Server name for nginx virtual host";
      };
    };
  };

  config = mkIf cfg.enable {
    # User and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    services = {
      # PostgreSQL setup
      postgresql = mkIf cfg.database.createLocally {
        enable = true;
        # Listen on localhost so Dify can connect via TCP (needed for sqlalchemy URL format)
        enableTCPIP = mkDefault (cfg.database.host == "127.0.0.1" || cfg.database.host == "localhost");
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
          }
        ];
        extensions = ps: optionals cfg.database.enablePgvector [ ps.pgvector ];
        # Allow local TCP connections from the dify user
        authentication = mkIf (cfg.database.host == "127.0.0.1" || cfg.database.host == "localhost") (
          pkgs.lib.mkForce ''
            # TYPE  DATABASE        USER            ADDRESS                 METHOD
            local   all             all                                     trust
            host    all             all             127.0.0.1/32            trust
            host    all             all             ::1/128                 trust
          ''
        );
      };

      # Redis setup
      redis.servers.dify = mkIf cfg.redis.createLocally {
        enable = true;
        inherit (cfg.redis) port;
        bind = cfg.redis.host;
      };

      # Nginx reverse proxy
      nginx = mkIf cfg.nginx.enable {
        enable = true;
        virtualHosts.${cfg.nginx.domain} = {
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.web.port}";
              proxyWebsockets = true;
            };
            "/api" = {
              proxyPass = "http://127.0.0.1:${toString cfg.api.port}";
              proxyWebsockets = true;
            };
            "/v1" = {
              proxyPass = "http://127.0.0.1:${toString cfg.api.port}";
              proxyWebsockets = true;
            };
            "/files" = {
              proxyPass = "http://127.0.0.1:${toString cfg.api.port}";
              proxyWebsockets = true;
            };
            "/console/api" = {
              proxyPass = "http://127.0.0.1:${toString cfg.api.port}";
              proxyWebsockets = true;
            };
          };
          extraConfig = ''
            client_max_body_size 15M;
            proxy_read_timeout 600s;
            proxy_connect_timeout 600s;
            proxy_send_timeout 600s;
          '';
        };
      };
    };

    # Create data directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/storage 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Common systemd service settings
    systemd.services =
      let
        commonServiceConfig = {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          StateDirectory = "dify";
          StateDirectoryMode = "0750";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [ cfg.dataDir ];
          Restart = "always";
          RestartSec = "10s";
        }
        // optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };

        commonAfter = [
          "network-online.target"
        ]
        ++ optionals cfg.database.createLocally [ "postgresql.service" ]
        ++ optionals cfg.redis.createLocally [ "redis-dify.service" ];

        commonWants = [ "network-online.target" ];

        commonRequires =
          optionals cfg.database.createLocally [ "postgresql.service" ]
          ++ optionals cfg.redis.createLocally [ "redis-dify.service" ];

        # Pre-start script to load SECRET_KEY
        secretKeySetup = optionalString (cfg.secretKeyFile != null) ''
          export SECRET_KEY="$(cat ${cfg.secretKeyFile})"
        '';

        dbPasswordSetup = optionalString (cfg.database.passwordFile != null) ''
          export DB_PASSWORD="$(cat ${cfg.database.passwordFile})"
        '';

        redisPasswordSetup = optionalString (cfg.redis.passwordFile != null) ''
          export REDIS_PASSWORD="$(cat ${cfg.redis.passwordFile})"
        '';
      in
      {
        # API server
        dify-api = {
          description = "Dify API Server";
          wantedBy = [ "multi-user.target" ];
          after = commonAfter;
          wants = commonWants;
          requires = commonRequires;

          environment = difyEnv;

          serviceConfig = commonServiceConfig // {
            Type = "simple";
            ExecStartPre = mkIf cfg.api.migrationEnabled (
              pkgs.writeShellScript "dify-api-migrate" ''
                ${secretKeySetup}
                ${dbPasswordSetup}
                ${redisPasswordSetup}
                exec ${cfg.package.api}/bin/dify-migrate
              ''
            );
            ExecStart = pkgs.writeShellScript "dify-api-start" ''
              ${secretKeySetup}
              ${dbPasswordSetup}
              ${redisPasswordSetup}
              exec ${cfg.package.api}/bin/dify-api \
                --bind ${cfg.api.host}:${toString cfg.api.port} \
                --workers ${toString cfg.api.workers} \
                --worker-class ${cfg.api.workerClass}
            '';
          };
        };

        # Celery worker
        dify-worker = {
          description = "Dify Celery Worker";
          wantedBy = [ "multi-user.target" ];
          after = commonAfter ++ [ "dify-api.service" ];
          wants = commonWants;
          requires = commonRequires;

          environment = difyEnv;

          serviceConfig = commonServiceConfig // {
            Type = "simple";
            ExecStart = pkgs.writeShellScript "dify-worker-start" ''
              ${secretKeySetup}
              ${dbPasswordSetup}
              ${redisPasswordSetup}
              exec ${cfg.package.api}/bin/dify-worker \
                ${optionalString (cfg.worker.concurrency != null) "-c ${toString cfg.worker.concurrency}"} \
                -Q ${cfg.worker.queues}
            '';
          };
        };

        # Celery beat scheduler
        dify-beat = {
          description = "Dify Celery Beat Scheduler";
          wantedBy = [ "multi-user.target" ];
          after = commonAfter ++ [ "dify-api.service" ];
          wants = commonWants;
          requires = commonRequires;

          environment = difyEnv;

          serviceConfig = commonServiceConfig // {
            Type = "simple";
            ExecStart = pkgs.writeShellScript "dify-beat-start" ''
              ${secretKeySetup}
              ${dbPasswordSetup}
              ${redisPasswordSetup}
              exec ${cfg.package.api}/bin/dify-beat
            '';
          };
        };

        # Web frontend
        dify-web = {
          description = "Dify Web Frontend";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          environment = {
            PORT = toString cfg.web.port;
            HOSTNAME = "0.0.0.0";
            NODE_ENV = "production";
            NEXT_TELEMETRY_DISABLED = "1";
            CONSOLE_API_URL = cfg.api.consoleApiUrl;
            APP_API_URL = cfg.api.appApiUrl;
          };

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = "${cfg.package.web}/lib/dify-web";
            ExecStart = "${cfg.package.web}/bin/dify-web";
            Restart = "always";
            RestartSec = "10s";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };
      };
  };
}
