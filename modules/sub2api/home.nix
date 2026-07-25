# home-manager wrapper: runs sub2api as the logged-in user, for hosts that
# cannot run NixOS. Requires `loginctl enable-linger <user>` so the unit
# survives logout.
#
# Note this manages neither PostgreSQL nor Redis — home-manager has no module
# for either — so point services.sub2api.database/redis at instances run some
# other way (a container, or the system package).
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sub2api;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    services.sub2api.dataDir = lib.mkDefault "${config.xdg.stateHome}/sub2api";

    # home-manager takes systemd's own capitalised sections, unlike NixOS's
    # description/serviceConfig, so map rather than splice.
    systemd.user.services.sub2api = {
      Unit = {
        Description = cfg._unit.description;
        After = [ "network-online.target" ];
      };
      # ProtectHome is deliberately absent: the state directory lives under
      # $HOME here, so hiding $HOME would break the service.
      Service = cfg._unit.serviceConfig;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
