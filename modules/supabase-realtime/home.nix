# home-manager wrapper: runs as the logged-in user on hosts that cannot run
# NixOS. Requires `loginctl enable-linger <user>` so the unit survives logout.
#
# openFirewall has no effect here — a user session cannot alter the firewall —
# and PostgreSQL is not managed, so point the database settings at an instance
# run some other way.
{ config, lib, ... }:
let
  cfg = config.services.supabase-realtime;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    services.supabase-realtime.dataDir = lib.mkDefault "${config.xdg.stateHome}/supabase-realtime";

    systemd.user.services.supabase-realtime = {
      Unit = {
        Description = cfg._unit.description;
        After = [ "network-online.target" ];
      };
      # ProtectHome is omitted: the state directory lives under $HOME.
      Service =
        cfg._unit.serviceConfig
        // lib.optionalAttrs cfg.migrate {
          ExecStartPre = "${cfg.package}/bin/migrate";
        };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
