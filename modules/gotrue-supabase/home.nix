# home-manager wrapper: runs as the logged-in user on hosts that cannot run
# NixOS. Requires `loginctl enable-linger <user>` so the unit survives logout.
#
# PostgreSQL is not managed here — home-manager has no module for it — so point
# databaseUrl at an instance run some other way.
{ config, lib, ... }:
let
  cfg = config.services.gotrue-supabase;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    # DynamicUser and ProtectHome are dropped: the first needs root, and the
    # second would hide the home directory this unit runs out of.
    systemd.user.services.gotrue-supabase = {
      Unit = {
        Description = cfg._unit.description;
        After = [ "network-online.target" ];
      };
      Service = cfg._unit.serviceConfig;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
