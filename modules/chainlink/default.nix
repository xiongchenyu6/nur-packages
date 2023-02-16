{ pkgs, config, lib, ... }:
with lib;
let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services.${serviceName};
in {
  options.services = {
    "${serviceName}" = {
      enable = mkEnableOption "Enables ${serviceName} service";
      apicredentialsFilePath = mkOption {
        description = lib.mdDoc
          "encrypted password file for bttc node to decrypt private key";
        type = types.path;
      };
      configFilePath = mkOption {
        description = lib.mdDoc
          "encrypted password file for bttc node to decrypt private key";
        type = types.path;
      };
      secretsFilePath = mkOption {
        description = lib.mdDoc
          "encrypted password file for bttc node to decrypt private key";
        type = types.path;
      };
    };
  };
  config = mkIf cfg.enable {
    systemd = {
      services = {
        "${serviceName}" = {
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
            "${pkgs.chainlink}/bin/chainlink -c ${cfg.configFilePath} -s ${cfg.secretsFilePath} node n -a ${cfg.apicredentialsFilePath}";
          postStart = "";
        };
      };
    };
    users.users."${serviceName}" = {
      description = "${serviceName} user";
      isSystemUser = true;
      group = serviceName;
    };
    users.groups."${serviceName}" = { };
  };
}
