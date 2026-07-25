# Kept as the NixOS module so existing `nixosModules.sub2api` consumers are
# unaffected by the split into common/nixos/home.
{ ... }:
{
  imports = [ ./nixos.nix ];
}
