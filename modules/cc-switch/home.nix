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

    # Deep-link URL scheme handler registration
    registerUrlScheme = mkOption {
      type = types.bool;
      default = true;
      description = "Register the ccswitch:// URL scheme handler for deep linking";
    };

    # Desktop integration
    desktopIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Install .desktop file and icons for desktop integration";
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

    # Register URL scheme handler for ccswitch:// deep links
    xdg.desktopEntries."cc-switch-url-handler" = mkIf (cfg.registerUrlScheme && cfg.desktopIntegration) {
      Type = "Application";
      Name = "CC Switch URL Handler";
      Exec = "${cfg.package}/bin/cc-switch --register-url-scheme %u";
      MimeType = "x-scheme-handler/ccswitch";
      NoDisplay = true;
      Terminal = false;
    };

    # Main desktop entry
    xdg.desktopEntries.cc-switch = mkIf cfg.desktopIntegration {
      Type = "Application";
      Name = "CC Switch";
      Comment = "Cross-platform desktop app for managing AI coding tools";
      Exec = "${cfg.package}/bin/cc-switch";
      Icon = "cc-switch";
      Terminal = false;
      Categories = "Development;Utility;";
      StartupNotify = true;
      MimeType = "x-scheme-handler/ccswitch;";
    };

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