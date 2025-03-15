{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.postgrest;

  # Helper function to convert boolean values to strings
  boolToString = b: if b then "true" else "false";

  # Generate the configuration file content - strip empty lines
  configFile = pkgs.writeText "postgrest.conf" (
    concatStringsSep "\n" (
      filter (l: l != "") [
        "admin-server-port = ${toString cfg."admin-server-port"}"
        "db-anon-role = \"${cfg."db-anon-role"}\""
        "db-channel = \"${cfg."db-channel"}\""
        "db-channel-enabled = ${boolToString cfg."db-channel-enabled"}"
        "db-config = ${boolToString cfg."db-config"}"
        (optionalString (cfg."db-pre-config" != null) "db-pre-config = \"${cfg."db-pre-config"}\"")
        "db-extra-search-path = \"${cfg."db-extra-search-path"}\""
        "db-max-rows = ${toString cfg."db-max-rows"}"
        "db-plan-enabled = ${boolToString cfg."db-plan-enabled"}"
        "db-pool = ${toString cfg."db-pool"}"
        (optionalString (cfg."db-pool-acquisition-timeout" != null)
          "db-pool-acquisition-timeout = ${toString cfg."db-pool-acquisition-timeout"}"
        )
        (optionalString (cfg."db-pool-max-lifetime" != null)
          "db-pool-max-lifetime = ${toString cfg."db-pool-max-lifetime"}"
        )
        (optionalString (cfg."db-pool-max-idletime" != null)
          "db-pool-max-idletime = ${toString cfg."db-pool-max-idletime"}"
        )
        (optionalString (cfg."db-pool-automatic-recovery" != null)
          "db-pool-automatic-recovery = ${boolToString cfg."db-pool-automatic-recovery"}"
        )
        (optionalString (cfg."db-pre-request" != null) "db-pre-request = \"${cfg."db-pre-request"}\"")
        "db-prepared-statements = ${boolToString cfg."db-prepared-statements"}"
        "db-schemas = \"${cfg."db-schemas"}\""
        "db-tx-end = \"${cfg."db-tx-end"}\""
        "db-uri = \"${cfg."db-uri"}\""
        (optionalString (cfg."jwt-aud" != null) "jwt-aud = \"${cfg."jwt-aud"}\"")
        (optionalString (
          cfg."jwt-role-claim-key" != null
        ) "jwt-role-claim-key = ${cfg."jwt-role-claim-key"}")
        (optionalString (cfg."jwt-secret" != null) "jwt-secret = \"${cfg."jwt-secret"}\"")
        (optionalString (cfg."jwt-secret-is-base64" != null)
          "jwt-secret-is-base64 = ${boolToString cfg."jwt-secret-is-base64"}"
        )
        (optionalString (cfg."jwt-cache-max-lifetime" != null)
          "jwt-cache-max-lifetime = ${toString cfg."jwt-cache-max-lifetime"}"
        )
        "log-level = \"${cfg."log-level"}\""
        "openapi-security-active = ${boolToString cfg."openapi-security-active"}"
        "openapi-mode = \"${cfg."openapi-mode"}\""
        (optionalString (
          cfg."openapi-server-proxy-uri" != null
        ) "openapi-server-proxy-uri = \"${cfg."openapi-server-proxy-uri"}\"")
        (optionalString (cfg."server-cors-allowed-origins" != null)
          "server-cors-allowed-origins = \"${cfg."server-cors-allowed-origins"}\""
        )
        "server-host = \"${cfg."server-host"}\""
        "server-port = ${toString cfg."server-port"}"
        "server-timing-enabled = ${boolToString cfg."server-timing-enabled"}"
        (optionalString (
          cfg."server-unix-socket" != null
        ) "server-unix-socket = \"${cfg."server-unix-socket"}\"")
        (optionalString (
          cfg."server-unix-socket-mode" != null
        ) "server-unix-socket-mode = \"${cfg."server-unix-socket-mode"}\"")
      ]
    )
  );
in
{
  options.services.postgrest = {
    enable = mkEnableOption "PostgREST service";

    package = mkOption {
      type = types.package;
      default = pkgs.postgrest;
      description = "The PostgREST package to use.";
    };

    "admin-server-port" = mkOption {
      type = types.int;
      default = 3001;
      description = "Admin server port used for checks.";
    };

    "db-anon-role" = mkOption {
      type = types.str;
      default = "api_anon";
      description = "Database role to use when no client authentication is provided.";
    };

    "db-channel" = mkOption {
      type = types.str;
      default = "pgrst";
      description = "Notification channel for reloading the schema cache.";
    };

    "db-channel-enabled" = mkOption {
      type = types.bool;
      default = true;
      description = "Enable or disable the notification channel.";
    };

    "db-config" = mkOption {
      type = types.bool;
      default = true;
      description = "Enable in-database configuration.";
    };

    "db-pre-config" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "postgrest.pre_config";
      description = "Function for in-database configuration.";
    };

    "db-extra-search-path" = mkOption {
      type = types.str;
      default = "api";
      description = "Extra schemas to add to the search_path of every request.";
    };

    "db-max-rows" = mkOption {
      type = types.int;
      default = 1000;
      description = "Limit rows in response.";
    };

    "db-plan-enabled" = mkOption {
      type = types.bool;
      default = true;
      description = "Allow getting the EXPLAIN plan through the 'Accept: application/vnd.pgrst.plan' header.";
    };

    "db-pool" = mkOption {
      type = types.int;
      default = 10;
      description = "Number of open connections in the pool.";
    };

    "db-pool-acquisition-timeout" = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 10;
      description = "Time in seconds to wait to acquire a slot from the connection pool.";
    };

    "db-pool-max-lifetime" = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 1800;
      description = "Time in seconds after which to recycle pool connections.";
    };

    "db-pool-max-idletime" = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 30;
      description = "Time in seconds after which to recycle unused pool connections.";
    };

    "db-pool-automatic-recovery" = mkOption {
      type = types.nullOr types.bool;
      default = null;
      example = true;
      description = "Allow automatic database connection retrying.";
    };

    "db-pre-request" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "stored_proc_name";
      description = "Stored proc to exec immediately after auth.";
    };

    "db-prepared-statements" = mkOption {
      type = types.bool;
      default = true;
      description = "Enable or disable prepared statements.";
    };

    "db-schemas" = mkOption {
      type = types.str;
      default = "api";
      description = "The name of which database schema to expose to REST clients.";
    };

    "db-tx-end" = mkOption {
      type = types.str;
      default = "commit";
      description = "How to terminate database transactions.";
      example = "commit | commit-allow-override | rollback | rollback-allow-override";
    };

    "db-uri" = mkOption {
      type = types.str;
      default = "postgres://api_authenticator:api_authenticator@localhost:5432/api";
      description = "The PostgreSQL connection URI.";
    };

    "jwt-aud" = mkOption {
      type = types.nullOr types.str;
      default = "zTJoNRBgJcE8PLecqdaFXQ38tND6PXP1";
      description = "JWT audience claim.";
    };

    "jwt-role-claim-key" = mkOption {
      type = types.nullOr types.str;
      default = ''".\"postgres/roles\"[0]"'';
      description = "Jspath to the role claim key.";
    };

    "jwt-secret" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "@./rsa.jwk.pub";
      description = "JSON Web Key for JWT auth.";
    };

    "jwt-secret-is-base64" = mkOption {
      type = types.nullOr types.bool;
      default = null;
      example = true;
      description = "Whether JWT secret is base64 encoded.";
    };

    "jwt-cache-max-lifetime" = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 0;
      description = "JWT Cache max lifetime. Disables caching with 0.";
    };

    "log-level" = mkOption {
      type = types.enum [
        "crit"
        "error"
        "warn"
        "info"
      ];
      default = "info";
      description = "Logging level.";
    };

    "openapi-mode" = mkOption {
      type = types.enum [
        "follow-privileges"
        "ignore-privileges"
        "disabled"
      ];
      default = "follow-privileges";
      description = "OpenAPI output mode.";
    };

    "openapi-security-active" = mkOption {
      type = types.bool;
      default = false;
      description = "Enable or disable OpenAPI security.";
    };

    "openapi-server-proxy-uri" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://localhost:3000";
      description = "Base url for the OpenAPI output.";
    };

    "server-cors-allowed-origins" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "*";
      description = "Configurable CORS origins.";
    };

    "server-host" = mkOption {
      type = types.str;
      default = "!4";
      description = "Server host address to bind to.";
    };

    "server-port" = mkOption {
      type = types.int;
      default = 3333;
      description = "Server port to listen on.";
    };

    "server-timing-enabled" = mkOption {
      type = types.bool;
      default = false;
      description = "Allow getting the request-response timing information through the Server-Timing header.";
    };

    "server-unix-socket" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/tmp/pgrst.sock";
      description = "Unix socket location, takes precedence over server-port if specified.";
    };

    "server-unix-socket-mode" = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "660";
      description = "Unix socket file mode. When none is provided, 660 is applied by default.";
    };

    user = mkOption {
      type = types.str;
      default = "postgrest";
      description = "User account under which PostgREST runs.";
    };

    group = mkOption {
      type = types.str;
      default = "postgrest";
      description = "Group under which PostgREST runs.";
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == "postgrest") {
      postgrest = {
        isSystemUser = true;
        group = cfg.group;
        description = "PostgREST service user";
      };
    };

    users.groups = mkIf (cfg.group == "postgrest") {
      postgrest = { };
    };

    systemd.services.postgrest = {
      description = "PostgREST Service";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "postgresql.service"
      ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/postgrest ${configFile}";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "10s";

        # Security hardening
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = "";
        RemoveIPC = true;
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };
  };
}
