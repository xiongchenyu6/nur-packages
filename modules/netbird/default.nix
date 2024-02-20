{ pkgs, config, lib, ... }:
with lib;
let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services."${serviceName}-server";
in {
  options.services = {
    "${serviceName}-server" = {
      enable = mkEnableOption "Enables ${serviceName} service";
      mgmtConfig = mkOption {
        type = types.path;
        description = "Path to management config file";
      };
      signalPort = mkOption {
        default = 8080;
        type = types.int;
        description = "Port for signal service";
      };
      mgmtPort = mkOption {
        default = 8081;
        type = types.int;
        description = "Port for management service";
      };
      logLevel = mkOption {
        default = "info";
        type = types.str;
      };
    };
  };
  config = mkIf cfg.enable {
    systemd = {
      services = {
        "netbird-signal" = {
          wantedBy = [ "multi-user.target" ];
          after = [ "networking.target" ];
          startLimitIntervalSec = 500;
          startLimitBurst = 5;
          preStart = "";
          onSuccess = [ ];
          onFailure = [ ];
          serviceConfig = {
            User = serviceName;
            RestartSec = "5s";
            WorkingDirectory = "/var/lib/${serviceName}";
            StateDirectory = serviceName;
            RuntimeDirectory = serviceName;
            CacheDirectory = serviceName;
            Type = "simple";
          };
          script = "${pkgs.netbird}/bin/netbird-signal run --port ${
              toString cfg.signalPort
            } --log-file console --log-level ${cfg.logLevel}";
        };
        "netbird-mgmt" = {
          wantedBy = [ "multi-user.target" ];
          after = [ "networking.target" ];
          startLimitIntervalSec = 500;
          startLimitBurst = 5;
          preStart = "";
          onSuccess = [ ];
          onFailure = [ ];
          serviceConfig = {
            User = serviceName;
            RestartSec = "5s";
            WorkingDirectory = "/var/lib/${serviceName}";
            StateDirectory = serviceName;
            RuntimeDirectory = serviceName;
            CacheDirectory = serviceName;
            Type = "simple";
          };
          script =
            "${pkgs.netbird}/bin/netbird-mgmt management --config ${cfg.mgmtConfig} --port ${
              toString cfg.mgmtPort
            } --log-file console --log-level ${cfg.logLevel} --single-account-mode-domain=netbird.trontech.link";
        };
      };
    };
    users.users."${serviceName}" = {
      description = "${serviceName} user";
      isSystemUser = true;
      group = serviceName;
      createHome = true;
    };
    users.groups."${serviceName}" = { };
  };
}
