# NixOS wrapper: system user and the full hardening set.
{ config, lib, ... }:
let
  cfg = config.services.postgrest;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "postgrest") {
      postgrest = {
        isSystemUser = true;
        group = cfg.group;
        description = "PostgREST service user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "postgrest") {
      postgrest = { };
    };

    systemd.services.postgrest = {
      inherit (cfg._unit) description;
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "postgresql.service"
      ];

      serviceConfig = cfg._unit.serviceConfig // {
        User = cfg.user;
        Group = cfg.group;

        # Everything below needs privileges the user manager does not have, so
        # it stays out of the shared unit and out of the home-manager wrapper.
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
      };
    };
  };
}
