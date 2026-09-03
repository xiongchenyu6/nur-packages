{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.sub2api;

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
      default = pkgs.sub2api;
      defaultText = literalExpression "pkgs.sub2api";
      description = ''
        Sub2API package to use. Packaged upstream in numtide/llm-agents.nix;
        the flake's nixosModules/homeModules export defaults this to that
        package, so `pkgs.sub2api` only matters when the module is imported
        by path (in which case the NUR overlay supplies it).
      '';
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

    dataDir = mkOption {
      type = types.path;
      description = ''
        Data directory. Defaulted by whichever wrapper is in use:
        /var/lib/sub2api on NixOS, $XDG_STATE_HOME/sub2api under home-manager.
      '';
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

    # Filled in below; the nixos/ home wrappers consume this so the unit body
    # is written exactly once.
    _unit = mkOption {
      type = types.attrs;
      internal = true;
      readOnly = true;
      description = ''
        Schema-neutral pieces of the unit. NixOS wants description/serviceConfig
        while home-manager wants Unit.Description/Service, so each wrapper maps
        these itself rather than passing the attrset through verbatim.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.sub2api._unit = {
      description = "Sub2API - AI API gateway platform";

      # Keys valid in a [Service] section either way.
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = cfg.dataDir;

        ExecStartPre = pkgs.writeShellScript "sub2api-pre-start" ''
          cp ${configFile} ${cfg.dataDir}/config.yaml
          chmod 600 ${cfg.dataDir}/config.yaml
        '';

        ExecStart = "${cfg.package}/bin/sub2api";

        Restart = "always";
        RestartSec = "10s";

        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
