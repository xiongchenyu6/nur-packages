{ config, lib, pkgs, ... }:
with lib;
let cfg = config.services.oci-arm-host-capacity;
in {
  options = {
    services = {
      oci-arm-host-capacity = {
        enable = mkEnableOption "Enables oci-arm-host-capacity service";

        envPath = mkOption {
          description = lib.mdDoc "envPath";
          default = "";
          type = types.path;
        };
      };
    };
  };
  config = {
    systemd = {
      services = mkIf cfg.enable {
        "oci-arm-host-capacity" = {
          description = "oci-arm-host-capacity Service Daemon";
          path = [ ];
          wantedBy = [ "multi-user.target" ];
          after = [ "networking.target" ];
          script = ''
            ${pkgs.php}/bin/php ${pkgs.oci-arm-host-capacity}/lib/vendor/hitrov/oci-arm-host-capacity/index.php
          '';
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = cfg.envPath;
          };
        };
      };
      timers = {
        "oci-arm-host-capacity" = {
          description = "Trigger a oci-arm-host-capacity service request";

          timerConfig = {
            OnBootSec = "5m";
            OnUnitInactiveSec = "5m";
            Unit = "oci-arm-host-capacity.service";
          };
          wantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
