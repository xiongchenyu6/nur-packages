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

  outputs =
    {
      nixpkgs,
      flake-parts,
      home-manager,
      ...
    }@inputs:
    let
      sharedOverlays = [
      ];
      sharedModules = [
      ];
      nixos-modules = [
        home-manager.nixosModules.home-manager

        (_: {
          nixpkgs = {
            # `nixpkgs.system` is deprecated; hostPlatform is the supported way
            # to pick the platform from inside a module.
            hostPlatform = "x86_64-linux";
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
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      perSystem =
        { pkgs, ... }:
        {
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              nixfmt
              nixd
            ];
          };
        };
      flake = {
        nixosConfigurations = {
          default = nixpkgs.lib.nixosSystem {
            modules = [ ./hosts/default ] ++ nixos-modules;
          };
        };
      };
    };
}
