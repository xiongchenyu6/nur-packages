# NixOS wrapper: a system unit under DynamicUser.
{ config, lib, ... }:
let
  cfg = config.services.gotrue-supabase;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    systemd.services.gotrue-supabase = {
      inherit (cfg._unit) description;
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = cfg._unit.serviceConfig // {
        # Both need root: DynamicUser allocates a transient system user, and
        # ProtectHome is pointless for a service that has no home. Neither is
        # available to the home-manager wrapper.
        DynamicUser = true;
        ProtectHome = true;
      };
    };
  };
}
