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
       let   sharedOverlays = [
        
      ];
      modules = [
      ];
      tf = builtins.fromJSON (builtins.readFile ./tf.json);
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
        nixosConfigurations =
          let
            ls-to-node =
              dir: override:
              builtins.foldl' (
                acc: f:
                acc
                // {
                  "${f}" = nixpkgs.lib.nixosSystem (
                    ({
                      specialArgs = {
                        profiles = {
                          share = import ./profiles/shares.nix { inherit lib; };
                        };
                        inherit tf;
                      };
                      modules = [
                        (
                          { modulesPath, ... }:
                          {
                            imports = [
                              "${modulesPath}/virtualisation/amazon-image.nix"
                              (dir + "/${f}")
                            ];
                            networking.hostName = f;
                            nixpkgs = {
                              config = {
                                allowUnfree = true;
                                allowBroken = true;
                                permittedInsecurePackages = [ "nodejs-16.20.2" ];
                              };
                              overlays = sharedOverlays;
                            };
                          }
                        )
                      ] ++ modules;
                    })
                    // (if (builtins.hasAttr f override) then override.${f} else { })
                  );
                }
              ) { } (builtins.attrNames (builtins.readDir dir));
          in
          (ls-to-node ./hosts {
            # nexus = {
            #   system = "aarch64-linux";
            # };
          });
      };
    };
}
