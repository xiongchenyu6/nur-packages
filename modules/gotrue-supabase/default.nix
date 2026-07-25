# Kept as the NixOS module so existing nixosModules.gotrue-supabase consumers
# are unaffected by the split into common/nixos/home.
{ ... }:
{
  imports = [ ./nixos.nix ];
}
