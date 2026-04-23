{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.supabase-realtime;

  realtimePkg = pkgs.callPackage ../../pkgs/supabase-realtime/package.nix { };

  baseEnvironment = {
    DB_HOST = cfg.database.host;
    DB_PORT = toString cfg.database.port;
    DB_USER = cfg.database.user;
    DB_NAME = cfg.database.name;
    PORT = toString cfg.port;
  };

  environment = baseEnvironment // cfg.settings;
  environmentList = mapAttrsToList (name: value: "${name}=${value}") environment;
in
{
  options.services.supabase-realtime = {
    enable = mkEnableOption "Supabase Realtime WebSocket server";

    package = mkOption {
      type = types.package;
      default = realtimePkg;
      description = "The supabase-realtime package to use.";
    };

    port = mkOption {
      type = types.port;
      default = 4000;
      description = "PORT — HTTP/WebSocket port to listen on.";
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "DB_HOST — PostgreSQL host.";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "DB_PORT — PostgreSQL port.";
      };

      user = mkOption {
        type = types.str;
        default = "supabase_admin";
        description = "DB_USER — PostgreSQL user.";
      };

      name = mkOption {
        type = types.str;
        default = "postgres";
        description = "DB_NAME — PostgreSQL database name.";
      };
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        SLOT_NAME_SUFFIX = "realtime";
        MAX_REPLICATION_LAG_MB = "100";
      };
      description = ''
        Additional environment variables passed to the realtime process.
        For secrets (DB_PASSWORD, SECRET_KEY_BASE, API_JWT_SECRET,
        METRICS_JWT_SECRET) prefer `environmentFiles`.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf (types.either types.path types.str);
      default = [ ];
      example = [ "/run/secrets/realtime.env" ];
      description = ''
        EnvironmentFile entries for secrets.
        Required variables: DB_PASSWORD, SECRET_KEY_BASE,
        API_JWT_SECRET, METRICS_JWT_SECRET.
      '';
    };

    migrate = mkOption {
      type = types.bool;
      default = true;
      description = "Run database migrations before starting the server.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the realtime port in the firewall.";
    };

    user = mkOption {
      type = types.str;
      default = "supabase-realtime";
      description = "System user to run realtime under.";
    };

    group = mkOption {
      type = types.str;
      default = "supabase-realtime";
      description = "System group to run realtime under.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/supabase-realtime";
      description = "State directory for the realtime service.";
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

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.supabase-realtime = {
      description = "Supabase Realtime WebSocket server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      wants = [ "network-online.target" ];

      preStart = mkIf cfg.migrate ''
        ${cfg.package}/bin/migrate
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = "supabase-realtime";
        StateDirectoryMode = "0750";

        ExecStart = "${cfg.package}/bin/realtime start";

        Environment = environmentList;
        EnvironmentFile = cfg.environmentFiles;

        Restart = "on-failure";
        RestartSec = "10s";

        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
        AmbientCapabilities = [ ];
      };
    };
  };
}
