_:
# Replace this with your real host configuration. `nixos-generate-config`
# writes a hardware-configuration.nix you can import alongside it.
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Set this to the NixOS release you first installed, and leave it alone
  # afterwards — it pins stateful defaults, not the package set.
  system.stateVersion = "26.05";
}
