{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cc-switch;
  package = pkgs.cc-switch;
in {
  options.programs.cc-switch = {
    enable = mkEnableOption "CC Switch - Cross-platform desktop app for managing AI coding tools";

    package = mkOption {
      type = types.package;
      default = package;
      description = "CC Switch package to use";
    };

    # Desktop integration (includes URL scheme handler via .desktop MimeType)
    desktopIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Install .desktop file and icons for desktop integration (includes ccswitch:// URL scheme)";
    };

    # Auto-start on login
    autostart = mkOption {
      type = types.bool;
      default = false;
      description = "Start CC Switch automatically on login";
    };

    # Additional environment variables
    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional environment variables to set for CC Switch";
    };

    # Custom settings file (optional)
    settingsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional path to a custom settings file";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # The package already includes a .desktop file with MimeType=x-scheme-handler/ccswitch
    # which registers the ccswitch:// URL scheme automatically
    # No additional xdg.desktopEntries needed

    # Auto-start
    systemd.user.services.cc-switch-autostart = mkIf cfg.autostart {
      description = "CC Switch auto-start";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/cc-switch";
        Restart = "on-failure";
        Environment = cfg.environmentVariables;
      };
    };

    # Environment variables
    home.sessionVariables = cfg.environmentVariables;
  };
}