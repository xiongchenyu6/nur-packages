# lan-mouse: Wayland-native software KVM (mouse/keyboard sharing over LAN).
# Runs as a user service tied to graphical-session.target — on niri/wlroots
# it captures input via layer-shell and emulates via virtual-pointer/keyboard.
#
# The daemon expects $XDG_CONFIG_HOME/lan-mouse/config.toml; `settings` is
# rendered there. The TLS certificate (lan-mouse.pem) is generated next to it
# on first start; peers must list each other's sha256 fingerprint in
# settings.authorized_fingerprints:
#   openssl x509 -in ~/.config/lan-mouse/lan-mouse.pem -noout -fingerprint -sha256
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.lan-mouse;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.services.lan-mouse = {
    enable = lib.mkEnableOption "lan-mouse software KVM daemon";

    package = lib.mkPackageOption pkgs "lan-mouse" { };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      example = lib.literalExpression ''
        {
          port = 4242;
          release_bind = [ "KeyA" "KeyS" "KeyD" "KeyF" ];
          authorized_fingerprints."bc:05:..." = "peer";
          clients = [
            {
              hostname = "peer";
              ips = [ "192.168.1.2" ];
              position = "right";
              activate_on_startup = true;
            }
          ];
        }
      '';
      description = "Contents of config.toml; see the lan-mouse README for keys.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."lan-mouse/config.toml".source =
      tomlFormat.generate "lan-mouse-config.toml" cfg.settings;

    systemd.user.services.lan-mouse = {
      Unit = {
        Description = "lan-mouse software KVM";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        # config.toml is a store symlink; restart on switch so edits apply.
        X-Restart-Triggers = [ config.xdg.configFile."lan-mouse/config.toml".source ];
      };
      Service = {
        ExecStart = "${lib.getExe cfg.package} daemon";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
