{ pkgs, config, lib, ... }:
with lib;
let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services.${serviceName};
in {
  options = {
    "${serviceName}" = {
      enable = mkEnableOption "Enables ${serviceName} service";
      privateKey = mkOption {
        type = types.str;
        default = "";
        description = "Private key for ${serviceName}";
      };
      network = mkOption {
        type = types.enum [ "mainnet" "testnet" ];
        default = "mainnet";
        description = "Network for ${serviceName}";
      };
    };
  };
  config = {
    systemd = {
      services = mkIf cfg.enable {
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
          RuntimeDirectory = serviceName;
          CacheDirectory = serviceName;
          Type = simple;
        };
        script =
          "${pkgs.java-tron}/bin/java-tron -p ${cfg.privateKey} --witness -c /data/java-tron/config.conf";
        postStart = "";
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
