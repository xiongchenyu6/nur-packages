{ nixos, homeManager, ... }:
{
  nixosModules.cc-switch = import ./nixos.nix;
  homeManagerModules.cc-switch = import ./home.nix;
}