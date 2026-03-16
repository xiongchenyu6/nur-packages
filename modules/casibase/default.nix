{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.casibase;

  casibasePkg = pkgs.callPackage ../../pkgs/casibase/package.nix { };

  boolToYesNo = b: if b then "yes" else "no";

  appConfContent = ''
    appname = ${cfg.appName}
    httpport = ${toString cfg.port}
    runmode = ${cfg.runMode}
    SessionOn = true
    copyrequestbody = ${boolToYesNo cfg.copyRequestBody}
    driverName = ${cfg.database.driver}
    dataSourceName = ${
      if cfg.database.driver == "postgres" then
        "user=${cfg.database.username} password=${cfg.database.password} host=${cfg.database.host} port=${toString cfg.database.port} sslmode=disable dbname=${cfg.database.name}"
      else
        "${cfg.database.username}:${cfg.database.password}@tcp(${cfg.database.host}:${toString cfg.database.port})/"
    }
    dbName = ${cfg.database.name}
    ${optionalString (cfg.redis.endpoint != "") ''
      redisEndpoint = ${cfg.redis.endpoint}
    ''}
    guacamoleEndpoint = ${cfg.guacamoleEndpoint}
    isDemoMode = ${boolToYesNo cfg.isDemoMode}
    disablePreviewMode = ${boolToYesNo cfg.disablePreviewMode}
    logPostOnly = ${boolToYesNo cfg.logPostOnly}
    landingFolder = ${cfg.landingFolder}
    casdoorEndpoint = ${cfg.casdoor.endpoint}
    clientId = ${cfg.casdoor.clientId}
    clientSecret = ${cfg.casdoor.clientSecret}
    casdoorOrganization = "${cfg.casdoor.organization}"
    casdoorApplication = "${cfg.casdoor.application}"
    redirectPath = ${cfg.redirectPath}
    cacheDir = "${cfg.dataDir}/cache"
    appDir = "${cfg.appDir}"
    isLocalIpDb = ${boolToYesNo cfg.isLocalIpDb}
    ${optionalString (cfg.audioStorageProvider != "") ''
      audioStorageProvider = "${cfg.audioStorageProvider}"
    ''}
    ${optionalString (cfg.providerDbName != "") ''
      providerDbName = "${cfg.providerDbName}"
    ''}
    ${optionalString (cfg.socks5Proxy != null) ''
      socks5Proxy = "${cfg.socks5Proxy}"
    ''}
    publicDomain = "${cfg.publicDomain}"
    adminDomain = "${cfg.adminDomain}"
    enableExtraPages = ${boolToYesNo cfg.enableExtraPages}
    shortcutPageItems = ${builtins.toJSON cfg.shortcutPageItems}
    usageEndpoints = ${builtins.toJSON cfg.usageEndpoints}
    iframeUrl = "${cfg.iframeUrl}"
    forceLanguage = "${cfg.forceLanguage}"
    defaultLanguage = "${cfg.defaultLanguage}"
    staticBaseUrl = "${cfg.staticBaseUrl}"
    htmlTitle = "${cfg.htmlTitle}"
    faviconUrl = "${cfg.faviconUrl}"
    logoUrl = "${cfg.logoUrl}"
    navbarHtml = "${cfg.navbarHtml}"
    footerHtml = "${cfg.footerHtml}"
    appUrl = "${cfg.appUrl}"
    frontendBaseDir = "${if cfg.frontendBaseDir != null then cfg.frontendBaseDir else "${cfg.package}/web/build"}"
    showGithubCorner = ${boolToYesNo cfg.showGithubCorner}
    defaultThemeType = "${cfg.theme.type}"
    defaultColorPrimary = "${cfg.theme.colorPrimary}"
    defaultBorderRadius = ${toString cfg.theme.borderRadius}
    defaultIsCompact = ${boolToYesNo cfg.theme.isCompact}
    avatarErrorUrl = "${cfg.avatarErrorUrl}"
    logConfig = ${builtins.toJSON cfg.logConfig}
  '';

in
{
  options.services.casibase = {
    enable = mkEnableOption "Casibase - AI Cloud OS / Knowledge Management";

    package = mkOption {
      type = types.package;
      default = casibasePkg;
      description = "Casibase package to use";
    };

    appName = mkOption {
      type = types.str;
      default = "casibase";
      description = "Application name";
    };

    port = mkOption {
      type = types.port;
      default = 14000;
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
      default = "casibase";
      description = "User under which casibase runs";
    };

    group = mkOption {
      type = types.str;
      default = "casibase";
      description = "Group under which casibase runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/casibase";
      description = "Data directory for casibase";
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
        default = "casibase";
        description = "Database username";
      };

      password = mkOption {
        type = types.str;
        default = "casibase";
        description = "Database password";
      };

      name = mkOption {
        type = types.str;
        default = "casibase";
        description = "Database name";
      };
    };

    redis = {
      endpoint = mkOption {
        type = types.str;
        default = "";
        description = "Redis endpoint (host:port). Empty to disable.";
      };
    };

    guacamoleEndpoint = mkOption {
      type = types.str;
      default = "127.0.0.1:4822";
      description = "Apache Guacamole endpoint";
    };

    isDemoMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable demo mode";
    };

    disablePreviewMode = mkOption {
      type = types.bool;
      default = false;
      description = "Disable preview mode";
    };

    logPostOnly = mkOption {
      type = types.bool;
      default = true;
      description = "Only log POST requests";
    };

    landingFolder = mkOption {
      type = types.str;
      default = "";
      description = "Landing folder path";
    };

    casdoor = {
      endpoint = mkOption {
        type = types.str;
        default = "http://localhost:8000";
        description = "Casdoor endpoint URL";
      };

      clientId = mkOption {
        type = types.str;
        description = "Casdoor OAuth client ID";
      };

      clientSecret = mkOption {
        type = types.str;
        default = "";
        description = "Casdoor OAuth client secret. Prefer using environmentFile for secrets.";
      };

      organization = mkOption {
        type = types.str;
        default = "built-in";
        description = "Casdoor organization name";
      };

      application = mkOption {
        type = types.str;
        default = "app-casibase";
        description = "Casdoor application name";
      };
    };

    redirectPath = mkOption {
      type = types.str;
      default = "/callback";
      description = "OAuth redirect path";
    };

    appDir = mkOption {
      type = types.str;
      default = "";
      description = "Application directory";
    };

    isLocalIpDb = mkOption {
      type = types.bool;
      default = false;
      description = "Use local IP database";
    };

    audioStorageProvider = mkOption {
      type = types.str;
      default = "";
      description = "Audio storage provider name";
    };

    providerDbName = mkOption {
      type = types.str;
      default = "";
      description = "Provider database name";
    };

    socks5Proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "127.0.0.1:10808";
      description = "SOCKS5 proxy address";
    };

    publicDomain = mkOption {
      type = types.str;
      default = "";
      description = "Public domain for the service";
    };

    adminDomain = mkOption {
      type = types.str;
      default = "";
      description = "Admin domain for the service";
    };

    enableExtraPages = mkOption {
      type = types.bool;
      default = false;
      description = "Enable extra pages";
    };

    shortcutPageItems = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Shortcut page items";
    };

    usageEndpoints = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Usage endpoints";
    };

    iframeUrl = mkOption {
      type = types.str;
      default = "";
      description = "IFrame URL";
    };

    forceLanguage = mkOption {
      type = types.str;
      default = "";
      description = "Force a specific language. Empty to auto-detect.";
    };

    defaultLanguage = mkOption {
      type = types.str;
      default = "en";
      description = "Default language";
    };

    staticBaseUrl = mkOption {
      type = types.str;
      default = "https://cdn.casibase.org";
      description = "Static base URL for assets";
    };

    htmlTitle = mkOption {
      type = types.str;
      default = "Casibase";
      description = "HTML page title";
    };

    faviconUrl = mkOption {
      type = types.str;
      default = "https://cdn.casibase.com/static/favicon.png";
      description = "Favicon URL";
    };

    logoUrl = mkOption {
      type = types.str;
      default = "https://cdn.casibase.org/img/casibase-logo_1200x256.png";
      description = "Logo URL";
    };

    navbarHtml = mkOption {
      type = types.str;
      default = "";
      description = "Custom navbar HTML";
    };

    footerHtml = mkOption {
      type = types.str;
      default = "";
      description = "Custom footer HTML";
    };

    appUrl = mkOption {
      type = types.str;
      default = "";
      description = "Application URL";
    };

    frontendBaseDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Frontend base directory. Defaults to the package's web/build directory.";
    };

    showGithubCorner = mkOption {
      type = types.bool;
      default = false;
      description = "Show GitHub corner link";
    };

    theme = {
      type = mkOption {
        type = types.str;
        default = "default";
        description = "Theme type";
      };

      colorPrimary = mkOption {
        type = types.str;
        default = "#5734d3";
        description = "Primary color";
      };

      borderRadius = mkOption {
        type = types.int;
        default = 6;
        description = "Border radius in pixels";
      };

      isCompact = mkOption {
        type = types.bool;
        default = false;
        description = "Use compact theme";
      };
    };

    avatarErrorUrl = mkOption {
      type = types.str;
      default = "https://cdn.casibase.org/gravatar/error.png";
      description = "Avatar error fallback URL";
    };

    logConfig = mkOption {
      type = types.attrs;
      default = {
        adapter = "file";
        filename = "logs/casibase.log";
        maxdays = 99999;
        perm = "0770";
      };
      description = "Logging configuration";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file with secrets";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Start casibase automatically on boot";
    };

    restartOnFailure = mkOption {
      type = types.bool;
      default = true;
      description = "Restart casibase on failure";
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
      "d ${cfg.dataDir}/cache 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.casibase = {
      description = "Casibase AI Cloud OS / Knowledge Management";
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
        StateDirectory = "casibase";
        StateDirectoryMode = "0750";

        ExecStartPre =
          let
            confDir = "${cfg.dataDir}/conf";
          in
          pkgs.writeShellScript "casibase-pre-start" ''
                      mkdir -p ${confDir}
                      mkdir -p ${cfg.dataDir}/logs
                      mkdir -p ${cfg.dataDir}/cache

                      # Write the configuration file
                      cat > ${confDir}/app.conf <<'EOF'
            ${appConfContent}
            EOF

                      # Set proper ownership
                      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          '';

        ExecStart = "${cfg.package}/bin/casibase -config ${cfg.dataDir}/conf/app.conf";

        Restart = mkIf cfg.restartOnFailure "always";
        RestartSec = "10s";

        # Security hardening
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
