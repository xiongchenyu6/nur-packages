# NixOS wrapper: dedicated system user, /var/lib state, firewall, system unit.
{ config, lib, ... }:
let
  cfg = config.services.supabase-realtime;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    services.supabase-realtime.dataDir = lib.mkDefault "/var/lib/supabase-realtime";

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.${cfg.group} = { };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.supabase-realtime = {
      inherit (cfg._unit) description;
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      wants = [ "network-online.target" ];

      preStart = lib.mkIf cfg.migrate ''
        ${cfg.package}/bin/migrate
      '';

      serviceConfig = cfg._unit.serviceConfig // {
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "supabase-realtime";
        StateDirectoryMode = "0750";
        # Fine here: the service has its own home. The home-manager wrapper
        # cannot use it, since its state directory is inside $HOME.
        ProtectHome = true;
      };
    };
  };
}
