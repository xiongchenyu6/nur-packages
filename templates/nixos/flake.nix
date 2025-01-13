# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { nixpkgs, flake-parts, home-manager, ... }@inputs:
    let
      sharedOverlays = [
      ];
      sharedModules = [
      ];
      nixos-modules = [
        home-manager.nixosModules.home-manager

        (_: {
          nixpkgs = {
            system = "x86_64-linux";
            config = {
              allowUnfree = true;
              allowBroken = true;
              android_sdk.accept_license = true;
            };
            overlays = sharedOverlays;
          };
          home-manager = {
            inherit sharedModules;
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        })
      ];
     in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
        devShells.default = pkgs.mkShell { buildInputs = with pkgs; [ ]; };
      };
      flake = {
          withSystem,
          inputs,
          lib,
          ...
        }: {
          nixosConfigurations = {
            default = nixpkgs.lib.nixosSystem { modules = [ ./hosts/default ] ++ nixos-modules;  };
          };
      };
    };
}
