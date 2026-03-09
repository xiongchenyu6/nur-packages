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
      default = 18060;
      type = types.int;
      description = "Port for the xiaohongshu-mcp server";
    };

    chromiumPackage = mkOption {
      type = types.package;
      default = pkgs.chromium;
      defaultText = literalExpression "pkgs.chromium";
      description = "Chromium package to use for browser automation";
    };

    display = mkOption {
      type = types.str;
      default = ":99";
      description = "X display to use (requires Xvfb or similar)";
    };

    workingDirectory = mkOption {
      type = types.str;
      default = "/var/lib/xiaohongshu-mcp";
      description = "Working directory for the service";
    };

    cookiesPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to cookies.json source to symlink into working directory";
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
      after = [
        "network-online.target"
        "xvfb.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "xvfb.service" ];
      description = "Xiaohongshu MCP Server";

      environment = {
        DISPLAY = cfg.display;
      };

      preStart = mkIf (cfg.cookiesPath != null) ''
        mkdir -p ${cfg.workingDirectory}
        ln -sfn ${cfg.cookiesPath} ${cfg.workingDirectory}/cookies.json
      '';

      script = ''
        exec ${xiaohongshu-mcp}/bin/xiaohongshu-mcp \
          --port :${toString cfg.port} \
          -bin ${cfg.chromiumPackage}/bin/chromium
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "5s";
        WorkingDirectory = cfg.workingDirectory;
        Type = "simple";
      };
    };

    users.users.${cfg.user} = mkIf (cfg.user == "xiaohongshu-mcp") {
      description = "xiaohongshu-mcp service user";
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "xiaohongshu-mcp") { };
  };
}
