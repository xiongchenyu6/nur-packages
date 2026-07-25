# Kept as the NixOS module so existing consumers are unaffected by the split.
{ ... }:
{
  imports = [ ./nixos.nix ];
}
