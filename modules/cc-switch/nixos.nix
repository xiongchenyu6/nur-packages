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
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # The package already includes a .desktop file with MimeType=x-scheme-handler/ccswitch
    # which registers the ccswitch:// URL scheme automatically
    # No additional systemd service needed

    # Desktop integration for autostart
    environment.etc."xdg/autostart/cc-switch.desktop" = mkIf (cfg.autostart && cfg.desktopIntegration) {
      source = pkgs.writeText "cc-switch.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=CC Switch
        Comment=Cross-platform desktop app for managing AI coding tools
        Exec=${cfg.package}/bin/cc-switch
        Icon=cc-switch
        Terminal=false
        Categories=Development;Utility;
        StartupNotify=true
      '';
    };

    # Environment variables
    environment.variables = cfg.environmentVariables;
  };
}