# NixOS wrapper: a dedicated system user, /var/lib state, and a system unit.
# Everything about how sub2api is configured and launched lives in common.nix.
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

  options.services.sub2api = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "sub2api";
      description = "User under which sub2api runs.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "sub2api";
      description = "Group under which sub2api runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sub2api.dataDir = lib.mkDefault "/var/lib/sub2api";

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

    systemd.services.sub2api = {
      inherit (cfg._unit) description;
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "postgresql.service"
        "redis.service"
      ];
      wants = [ "network-online.target" ];
      path = [ config.services.postgresql.package ];
      environment.HOME = cfg.dataDir;
      serviceConfig = cfg._unit.serviceConfig // {
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "sub2api";
        StateDirectoryMode = "0750";
        # Safe here because the service runs as its own user whose home is the
        # state dir; the home-manager wrapper omits it for the opposite reason.
        ProtectHome = true;
      };
    };
  };
}
