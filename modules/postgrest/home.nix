# home-manager wrapper: runs as the logged-in user on hosts that cannot run
# NixOS. Requires `loginctl enable-linger <user>` so the unit survives logout.
#
# The hardening here is the subset a user unit can actually apply. Directives
# needing privileges — CapabilityBoundingSet, DeviceAllow, PrivateUsers,
# ProtectClock, ProtectKernel*, RemoveIPC and friends — are silently ignored or
# refused by the user manager, so they are deliberately not set.
{ config, lib, ... }:
let
  cfg = config.services.postgrest;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    systemd.user.services.postgrest = {
      Unit = {
        Description = cfg._unit.description;
        After = [ "network.target" ];
      };
      Service = cfg._unit.serviceConfig;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
