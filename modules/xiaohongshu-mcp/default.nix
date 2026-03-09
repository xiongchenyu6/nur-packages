{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.xiaohongshu-mcp;
  xiaohongshu-mcp = pkgs.callPackage ../../pkgs/xiaohongshu-mcp/package.nix { };
in
{
  options.services.xiaohongshu-mcp = {
    enable = mkEnableOption "Enables xiaohongshu-mcp service";

    port = mkOption {
      default = 8080;
      type = types.int;
      description = "Port for the xiaohongshu-mcp server";
    };

    cookieFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing the xiaohongshu cookie for authentication";
    };

    user = mkOption {
      default = "xiaohongshu-mcp";
      type = types.str;
      description = "User to run xiaohongshu-mcp as";
    };

    group = mkOption {
      default = "xiaohongshu-mcp";
      type = types.str;
      description = "Group to run xiaohongshu-mcp as";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.xiaohongshu-mcp = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Xiaohongshu MCP Server";

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "xiaohongshu-mcp";
        WorkingDirectory = "/var/lib/xiaohongshu-mcp";
        Type = "simple";
      };

      script =
        let
          cookieArg =
            if cfg.cookieFile != null then
              "--cookie-file ${cfg.cookieFile}"
            else
              "";
        in
        "${xiaohongshu-mcp}/bin/xiaohongshu-mcp --port ${toString cfg.port} ${cookieArg}";
    };

    users.users.${cfg.user} = mkIf (cfg.user == "xiaohongshu-mcp") {
      description = "xiaohongshu-mcp service user";
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "xiaohongshu-mcp") { };
  };
}
