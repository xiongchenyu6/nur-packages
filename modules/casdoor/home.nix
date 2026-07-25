# home-manager wrapper: runs as the logged-in user on hosts that cannot run
# NixOS. Requires `loginctl enable-linger <user>` so the unit survives logout.
#
# The only real constraint versus NixOS is port numbers: a user unit cannot be
# granted CAP_NET_BIND_SERVICE, so LDAP has to move off 389/636. Both are
# options, so this is a configuration change rather than a missing feature.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.casdoor;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    services.casdoor.dataDir = lib.mkDefault "${config.xdg.stateHome}/casdoor";

    assertions = [
      {
        assertion = cfg.port >= 1024 && cfg.ldap.serverPort >= 1024 && cfg.ldap.ldapsServerPort >= 1024;
        message = ''
          casdoor under home-manager cannot bind ports below 1024: a user unit
          gets no CAP_NET_BIND_SERVICE. Currently port=${toString cfg.port},
          ldap.serverPort=${toString cfg.ldap.serverPort},
          ldap.ldapsServerPort=${toString cfg.ldap.ldapsServerPort}.
          Raise them, or run casdoor through the NixOS module instead.
        '';
      }
    ];

    home.packages = [ cfg.package ];

    systemd.user.services.casdoor = {
      Unit = {
        Description = cfg._unit.description;
        After = [ "network-online.target" ];
      };
      # No chown in pre-start: everything already belongs to this user.
      # ProtectHome is omitted, since the state directory lives under $HOME.
      Service = cfg._unit.serviceConfig // {
        Environment = [ "HOME=${cfg.dataDir}" ];
        ExecStartPre = pkgs.writeShellScript "casdoor-pre-start" cfg._unit.preStartBody;
      };
      Install.WantedBy = lib.optionals cfg.autoStart [ "default.target" ];
    };
  };
}
