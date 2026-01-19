{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.casdoor;

  casdoorPkg = pkgs.callPackage ../../pkgs/casdoor/package.nix { };

  # Helper to convert boolean to yes/no for casdoor config
  boolToYesNo = b: if b then "yes" else "no";

  # Generate the app.conf content
  appConfContent = ''
    appname = ${cfg.appName}
    httpport = ${toString cfg.port}
    runmode = ${cfg.runMode}
    copyrequestbody = ${boolToYesNo cfg.copyRequestBody}
    driverName = ${cfg.database.driver}
    dataSourceName = ${
      if cfg.database.driver == "postgres" then
        "host=${cfg.database.host} port=${toString cfg.database.port} user=${cfg.database.username} dbname=${cfg.database.name} password=${cfg.database.password} sslmode=disable"
      else
        "${cfg.database.username}:${cfg.database.password}@tcp(${cfg.database.host}:${toString cfg.database.port})/"
    }
    dbName = ${cfg.database.name}
    tableNamePrefix = ${cfg.database.tablePrefix}
    showSql = ${boolToYesNo cfg.database.showSql}
    ${optionalString (cfg.redis.enable) ''
      redisEndpoint = ${cfg.redis.host}:${toString cfg.redis.port}
    ''}
    ${optionalString (cfg.defaultStorageProvider != null) ''
      defaultStorageProvider = ${cfg.defaultStorageProvider}
    ''}
    isCloudIntranet = ${boolToYesNo cfg.isCloudIntranet}
    authState = "${cfg.authState}"
    ${optionalString (cfg.socks5Proxy != null) ''
      socks5Proxy = "${cfg.socks5Proxy}"
    ''}
    verificationCodeTimeout = ${toString cfg.verificationCodeTimeout}
    initScore = ${toString cfg.initScore}
    logPostOnly = ${boolToYesNo cfg.logPostOnly}
    isUsernameLowered = ${boolToYesNo cfg.isUsernameLowered}
    ${optionalString (cfg.origin != null) ''
      origin = "${cfg.origin}"
    ''}
    ${optionalString (cfg.originFrontend != null) ''
      originFrontend = "${cfg.originFrontend}"
    ''}
    staticBaseUrl = "${cfg.staticBaseUrl}"
    isDemoMode = ${boolToYesNo cfg.isDemoMode}
    batchSize = ${toString cfg.batchSize}
    enableErrorMask = ${boolToYesNo cfg.enableErrorMask}
    enableGzip = ${boolToYesNo cfg.enableGzip}
    ${optionalString (cfg.inactiveTimeoutMinutes != null) ''
      inactiveTimeoutMinutes = ${toString cfg.inactiveTimeoutMinutes}
    ''}
    ldapServerPort = ${toString cfg.ldap.serverPort}
    ldapsCertId = "${cfg.ldap.ldapsCertId}"
    ldapsServerPort = ${toString cfg.ldap.ldapsServerPort}
    radiusServerPort = ${toString cfg.radius.serverPort}
    radiusDefaultOrganization = "${cfg.radius.defaultOrganization}"
    radiusSecret = "${cfg.radius.secret}"
    quota = ${builtins.toJSON cfg.quota}
    logConfig = ${builtins.toJSON cfg.logConfig}
    initDataNewOnly = ${boolToYesNo cfg.initDataNewOnly}
    initDataFile = "${cfg.initDataFile}"
    frontendBaseDir = "${cfg.frontendBaseDir}"
  '';

in
{
  options.services.casdoor = {
    enable = mkEnableOption "Casdoor - Identity and Access Management";

    package = mkOption {
      type = types.package;
      default = casdoorPkg;
      description = "Casdoor package to use";
    };

    appName = mkOption {
      type = types.str;
      default = "casdoor";
      description = "Application name";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "HTTP port to listen on";
    };

    runMode = mkOption {
      type = types.enum [
        "dev"
        "prod"
      ];
      default = "prod";
      description = "Run mode (dev or prod)";
    };

    copyRequestBody = mkOption {
      type = types.bool;
      default = true;
      description = "Copy request body";
    };

    user = mkOption {
      type = types.str;
      default = "casdoor";
      description = "User under which casdoor runs";
    };

    group = mkOption {
      type = types.str;
      default = "casdoor";
      description = "Group under which casdoor runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/casdoor";
      description = "Data directory for casdoor";
    };

    database = {
      driver = mkOption {
        type = types.enum [
          "mysql"
          "postgres"
          "sqlite3"
          "mssql"
        ];
        default = "postgres";
        description = "Database driver";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Database host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "Database port";
      };

      username = mkOption {
        type = types.str;
        default = "casdoor";
        description = "Database username";
      };

      password = mkOption {
        type = types.str;
        default = "casdoor";
        description = "Database password";
      };

      name = mkOption {
        type = types.str;
        default = "casdoor";
        description = "Database name";
      };

      tablePrefix = mkOption {
        type = types.str;
        default = "";
        description = "Database table prefix";
      };

      showSql = mkOption {
        type = types.bool;
        default = false;
        description = "Show SQL queries in logs";
      };
    };

    redis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Redis";
      };

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
    };

    defaultStorageProvider = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "AwsS3";
      description = "Default storage provider";
    };

    isCloudIntranet = mkOption {
      type = types.bool;
      default = false;
      description = "Enable cloud intranet mode";
    };

    authState = mkOption {
      type = types.str;
      default = "casdoor";
      description = "Auth state";
    };

    socks5Proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "127.0.0.1:10808";
      description = "SOCKS5 proxy address";
    };

    verificationCodeTimeout = mkOption {
      type = types.int;
      default = 10;
      description = "Verification code timeout in minutes";
    };

    initScore = mkOption {
      type = types.int;
      default = 0;
      description = "Initial score for new users";
    };

    logPostOnly = mkOption {
      type = types.bool;
      default = true;
      description = "Only log POST requests";
    };

    isUsernameLowered = mkOption {
      type = types.bool;
      default = false;
      description = "Convert usernames to lowercase";
    };

    origin = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "CORS origin for API";
    };

    originFrontend = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "CORS origin for frontend";
    };

    staticBaseUrl = mkOption {
      type = types.str;
      default = "https://cdn.casbin.org";
      description = "Static base URL for assets";
    };

    isDemoMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable demo mode";
    };

    batchSize = mkOption {
      type = types.int;
      default = 100;
      description = "Batch size for operations";
    };

    enableErrorMask = mkOption {
      type = types.bool;
      default = false;
      description = "Enable error masking";
    };

    enableGzip = mkOption {
      type = types.bool;
      default = true;
      description = "Enable gzip compression";
    };

    inactiveTimeoutMinutes = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Inactive session timeout in minutes";
    };

    ldap = {
      serverPort = mkOption {
        type = types.port;
        default = 389;
        description = "LDAP server port";
      };

      ldapsCertId = mkOption {
        type = types.str;
        default = "";
        description = "LDAPS certificate ID";
      };

      ldapsServerPort = mkOption {
        type = types.port;
        default = 636;
        description = "LDAPS server port";
      };
    };

    radius = {
      serverPort = mkOption {
        type = types.port;
        default = 1812;
        description = "RADIUS server port";
      };

      defaultOrganization = mkOption {
        type = types.str;
        default = "built-in";
        description = "Default organization for RADIUS";
      };

      secret = mkOption {
        type = types.str;
        default = "secret";
        description = "RADIUS secret";
      };
    };

    quota = mkOption {
      type = types.attrsOf types.int;
      default = {
        organization = -1;
        user = -1;
        application = -1;
        provider = -1;
      };
      description = "Resource quotas";
    };

    logConfig = mkOption {
      type = types.attrs;
      default = {
        adapter = "file";
        filename = "logs/casdoor.log";
        maxdays = 99999;
        perm = "0770";
      };
      description = "Logging configuration";
    };

    initDataNewOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Only initialize data if database is empty";
    };

    initDataFile = mkOption {
      type = types.str;
      default = "./init_data.json";
      description = "Path to initial data file";
    };

    frontendBaseDir = mkOption {
      type = types.str;
      default = "../cc_0";
      description = "Frontend base directory";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file with secrets";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Start casdoor automatically on boot";
    };

    restartOnFailure = mkOption {
      type = types.bool;
      default = true;
      description = "Restart casdoor on failure";
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
      "d ${cfg.dataDir}/conf 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/object 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.casdoor = {
      description = "Casdoor Identity and Access Management";
      wantedBy = optionals cfg.autoStart [ "multi-user.target" ];
      after = [
        "network-online.target"
        "systemd-tmpfiles-setup.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "systemd-tmpfiles-setup.service" ];

      environment = {
        HOME = cfg.dataDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = "casdoor";
        StateDirectoryMode = "0750";

        ExecStartPre =
          let
            confDir = "${cfg.dataDir}/conf";
          in
          pkgs.writeShellScript "casdoor-pre-start" ''
                      mkdir -p ${confDir}
                      mkdir -p ${cfg.dataDir}/logs
                      mkdir -p ${cfg.dataDir}/object

                      # Write the configuration file
                      cat > ${confDir}/app.conf <<'EOF'
            ${appConfContent}
            EOF

                      # Set proper ownership
                      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          '';

        ExecStart = "${cfg.package}/bin/casdoor -config ${cfg.dataDir}/conf/app.conf";

        Restart = mkIf cfg.restartOnFailure "always";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
