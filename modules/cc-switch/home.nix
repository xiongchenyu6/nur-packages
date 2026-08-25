{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.cc-switch;
  package = pkgs.cc-switch;
in
{
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

    # On every start the Tauri deep-link plugin rewrites this file with
    # Exec=<current_exe()>. For the extracted AppImage that resolves to the
    # unwrapped binary, which has no usable RPATH and dies on libfontconfig,
    # so the handler it installs never launches. Own the file declaratively —
    # home-manager links it read-only from the store, the plugin's write
    # fails, and the handler keeps pointing at the wrapper.
    #
    # Both this and the package's own cc-switch.desktop claim the scheme, so
    # either one being picked works; mimeapps.list only decides which is
    # preferred (the plugin also rewrites that entry to point here).
    xdg.dataFile."applications/cc-switch-handler.desktop" = mkIf cfg.desktopIntegration {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=CC Switch
        Exec=${cfg.package}/bin/cc-switch %u
        Terminal=false
        MimeType=x-scheme-handler/ccswitch
        NoDisplay=true
      '';
    };

    xdg.mimeApps.defaultApplications = mkIf cfg.desktopIntegration {
      "x-scheme-handler/ccswitch" = "cc-switch.desktop";
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
