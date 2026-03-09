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
      default = "/var/lib/openclaw/.openclaw/workspace/cookies.json";
      description = "Path to cookies.json source to symlink into working directory";
    };

    extraChromeFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags to pass to Chromium";
    };

    headless = mkOption {
      type = types.bool;
      default = true;
      description = "Run Chromium in headless mode";
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
        # Fix chrome_crashpad_handler: --database is required error
        # in headless/server environments
        XDG_CONFIG_HOME = "${cfg.workingDirectory}/.config";
        XDG_CACHE_HOME = "${cfg.workingDirectory}/.cache";
        # Disable crash reporter in containers/headless environments
        CHROME_DEVEL_SANDBOX = "";
      };

      preStart = mkIf (cfg.cookiesPath != null) ''
        mkdir -p ${cfg.workingDirectory}
        mkdir -p ${cfg.workingDirectory}/.config
        mkdir -p ${cfg.workingDirectory}/.cache
        ln -sfn ${cfg.cookiesPath} ${cfg.workingDirectory}/cookies.json
      '';

      script =
        let
          chromeFlags = lib.concatStringsSep " " cfg.extraChromeFlags;
        in
        ''
          exec ${xiaohongshu-mcp}/bin/xiaohongshu-mcp \
            --port :${toString cfg.port} \
            -bin ${cfg.chromiumPackage}/bin/chromium \
            -headless=${if cfg.headless then "true" else "false"}
        '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "5s";
        StateDirectory = "xiaohongshu-mcp";
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
