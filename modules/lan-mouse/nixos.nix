# NixOS side of lan-mouse: the daemon itself runs per user (see home.nix),
# but only the system can open the firewall for its listen port.
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.lan-mouse;
in
{
  options.services.lan-mouse = {
    enable = lib.mkEnableOption "lan-mouse software KVM (firewall/system side)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4242;
      description = "UDP port the per-user lan-mouse daemon listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the listen port in the firewall.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.openFirewall) {
    networking.firewall.allowedUDPPorts = [ cfg.port ];
  };
}
