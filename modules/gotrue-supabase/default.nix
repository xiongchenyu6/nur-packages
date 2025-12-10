{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.gotrue-supabase;

  formatValue =
    v:
    if builtins.isBool v then
      boolToString v
    else if builtins.isInt v then
      toString v
    else
      v;

  baseEnvironment = {
    GOTRUE_SITE_URL = cfg.siteUrl;
    API_EXTERNAL_URL = cfg.apiExternalUrl;
    DB_DATABASE_URL = cfg.databaseUrl;
    GOTRUE_JWT_SECRET = cfg.jwtSecret;
    GOTRUE_DB_DRIVER = cfg.dbDriver;
    GOTRUE_API_HOST = cfg.listenAddress;
    API_PORT = cfg.apiPort;
    LOG_LEVEL = cfg.logLevel;
  };
  environment = mapAttrs (_: formatValue) (
    filterAttrs (_: v: v != null) (baseEnvironment // cfg.settings)
  );
  environmentList = mapAttrsToList (name: value: "${name}=${value}") environment;
in
{
  options.services.gotrue-supabase = {
    enable = mkEnableOption "Supabase Auth (GoTrue) service";

    package = mkOption {
      type = types.package;
      default = pkgs.gotrue-supabase;
      description = "Package providing the GoTrue server binary.";
    };

    siteUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://example.netlify.com/";
      description = "GOTRUE_SITE_URL used to construct callback links.";
    };

    apiExternalUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://auth.example.com";
      description = "API_EXTERNAL_URL advertising the public endpoint.";
    };

    databaseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "postgresql://postgres:password@localhost:5432/postgres";
      description = "DB_DATABASE_URL (or DATABASE_URL) connection string.";
    };

    jwtSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "supersecretvalue";
      description = "GOTRUE_JWT_SECRET used to sign issued tokens.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "GOTRUE_API_HOST binding address.";
    };

    apiPort = mkOption {
      type = types.port;
      default = 8081;
      description = "API_PORT / GOTRUE_API_PORT port to listen on.";
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      description = "LOG_LEVEL for the GoTrue server.";
    };

    dbDriver = mkOption {
      type = types.str;
      default = "postgres";
      description = "GOTRUE_DB_DRIVER to use (postgres only).";
    };

    settings = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.bool
        ]
      );
      default = { };
      example = {
        GOTRUE_EXTERNAL_EMAIL_ENABLED = false;
        GOTRUE_SMTP_HOST = "smtp.example.com";
      };
      description = ''
        Additional GoTrue environment variables. Values are serialized as strings,
        so avoid storing secrets here unless acceptable to embed in the world-readable
        Nix store. For secrets prefer `environmentFiles`.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf (types.either types.path types.str);
      default = [ ];
      example = [ "/run/keys/gotrue.env" ];
      description = "EnvironmentFile entries (useful for secrets such as JWT secret).";
    };
  };

  config = mkIf cfg.enable {
    warnings =
      (optional (cfg.environmentFiles == [ ] && cfg.siteUrl == null && !(cfg.settings ? GOTRUE_SITE_URL))
        "services.gotrue-supabase.siteUrl unset; set siteUrl, settings.GOTRUE_SITE_URL, or use an environment file."
      )
      ++ (optional
        (cfg.environmentFiles == [ ] && cfg.apiExternalUrl == null && !(cfg.settings ? API_EXTERNAL_URL))
        "services.gotrue-supabase.apiExternalUrl unset; set apiExternalUrl, settings.API_EXTERNAL_URL, or use an environment file."
      )
      ++ (optional
        (cfg.environmentFiles == [ ] && cfg.databaseUrl == null && !(cfg.settings ? DB_DATABASE_URL))
        "services.gotrue-supabase.databaseUrl unset; set databaseUrl, settings.DB_DATABASE_URL, or use an environment file."
      )
      ++ (optional
        (cfg.environmentFiles == [ ] && cfg.jwtSecret == null && !(cfg.settings ? GOTRUE_JWT_SECRET))
        "services.gotrue-supabase.jwtSecret unset; set jwtSecret, settings.GOTRUE_JWT_SECRET, or use an environment file."
      );

    systemd.services.gotrue-supabase = {
      description = "Supabase Auth (GoTrue)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/auth serve";
        Environment = environmentList;
        EnvironmentFile = cfg.environmentFiles;
        Restart = "on-failure";
        DynamicUser = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        AmbientCapabilities = [ ];
      };
    };
  };
}
