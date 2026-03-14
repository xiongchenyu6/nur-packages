{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.sub2api;

  sub2apiPkg = pkgs.callPackage ../../pkgs/sub2api/package.nix { };

  configFile = pkgs.writeText "config.yaml" (
    builtins.toJSON {
      server = {
        host = cfg.host;
        port = cfg.port;
        mode = "release";
      };
      database = {
        host = cfg.database.host;
        port = cfg.database.port;
        user = cfg.database.user;
        password = cfg.database.password;
        dbname = cfg.database.name;
        sslmode = cfg.database.sslMode;
      };
      redis = {
        host = cfg.redis.host;
        port = cfg.redis.port;
        password = cfg.redis.password;
        db = cfg.redis.db;
      };
      jwt = {
        secret = cfg.jwtSecret;
        expire_hour = cfg.jwtExpireHour;
      };
      totp = {
        encryption_key = cfg.totpEncryptionKey;
      };
      run_mode = cfg.runMode;
    }
  );
in
{
  options.services.sub2api = {
    enable = mkEnableOption "Sub2API - AI API gateway platform";

    package = mkOption {
      type = types.package;
      default = sub2apiPkg;
      description = "Sub2API package to use";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address to listen on";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "HTTP port to listen on";
    };

    runMode = mkOption {
      type = types.enum [
        "standard"
        "simple"
      ];
      default = "standard";
      description = "Run mode (standard or simple)";
    };

    user = mkOption {
      type = types.str;
      default = "sub2api";
      description = "User under which sub2api runs";
    };

    group = mkOption {
      type = types.str;
      default = "sub2api";
      description = "Group under which sub2api runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/sub2api";
      description = "Data directory for sub2api";
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "PostgreSQL port";
      };

      user = mkOption {
        type = types.str;
        default = "sub2api";
        description = "PostgreSQL username";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = "PostgreSQL password. Consider using environmentFile instead.";
      };

      name = mkOption {
        type = types.str;
        default = "sub2api";
        description = "PostgreSQL database name";
      };

      sslMode = mkOption {
        type = types.str;
        default = "disable";
        description = "PostgreSQL SSL mode";
      };
    };

    redis = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Redis host";
      };

      port = mkOption {
        type = types.port;
        default = 6379;
        description = "Redis port";
      };

      password = mkOption {
        type = types.str;
        default = "";
        description = "Redis password";
      };

      db = mkOption {
        type = types.int;
        default = 0;
        description = "Redis database number";
      };
    };

    jwtSecret = mkOption {
      type = types.str;
      default = "";
      description = "JWT secret key. Consider using environmentFile instead.";
    };

    jwtExpireHour = mkOption {
      type = types.int;
      default = 24;
      description = "JWT token expiration in hours";
    };

    totpEncryptionKey = mkOption {
      type = types.str;
      default = "";
      description = "TOTP encryption key (32-byte hex). Consider using environmentFile instead.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file with secrets (DATABASE_PASSWORD, JWT_SECRET, TOTP_ENCRYPTION_KEY, etc.)";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.sub2api = {
      description = "Sub2API - AI API gateway platform";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
        "redis.service"
      ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = cfg.dataDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = "sub2api";
        StateDirectoryMode = "0750";

        ExecStartPre = pkgs.writeShellScript "sub2api-pre-start" ''
          cp ${configFile} ${cfg.dataDir}/config.yaml
          chmod 600 ${cfg.dataDir}/config.yaml
        '';

        ExecStart = "${cfg.package}/bin/sub2api";

        Restart = "always";
        RestartSec = "10s";

        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
