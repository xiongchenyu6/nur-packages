# NixOS wrapper: system user, /var/lib state, and the capability casdoor needs
# to bind LDAP's privileged ports.
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
    services.casdoor.dataDir = lib.mkDefault "/var/lib/casdoor";

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.casdoor = {
      inherit (cfg._unit) description;
      wantedBy = lib.optionals cfg.autoStart [ "multi-user.target" ];
      after = [
        "network-online.target"
        "systemd-tmpfiles-setup.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "systemd-tmpfiles-setup.service" ];

      path = [ pkgs.lsof ];
      environment.HOME = cfg.dataDir;

      serviceConfig = cfg._unit.serviceConfig // {
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "casdoor";
        StateDirectoryMode = "0750";

        ExecStartPre = pkgs.writeShellScript "casdoor-pre-start" (
          cfg._unit.preStartBody
          + ''

            # Set proper ownership
            chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          ''
        );

        # Fine here: the service has its own home. The home-manager wrapper
        # cannot use it, since its state directory is inside $HOME.
        ProtectHome = true;

        # Lets casdoor bind LDAP 389 / LDAPS 636. A user unit cannot be granted
        # this, which is why the home-manager wrapper requires unprivileged
        # ports instead.
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      };
    };

    environment.systemPackages = [ cfg.package ];
  };
}
