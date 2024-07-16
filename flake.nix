{
  description = "My personal NUR repository";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oci-arm-host-capacity-src = {
      url = "github:hitrov/oci-arm-host-capacity";
      flake = false;
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      dream2nix,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, lib, ... }:
        {
          packages = import ./. {
            inherit lib pkgs;
            ci = false;
            inherit inputs;
            inherit dream2nix;
          };
          apps = {
            ci = {
              type = "app";
              program = builtins.toString (
                pkgs.writeShellScript "ci" ''
                  if [ "$1" == "" ]; then
                  echo "Usage: ci <system>";
                  exit 1;
                  fi
                  exec ${pkgs.nix-build-uncached}/bin/nix-build-uncached ci.nix -A $1 --show-trace
                ''
              );
            };

            update = {
              type = "app";
              program = builtins.toString (
                pkgs.writeShellScript "update" ''
                  nix flake update
                  # ${pkgs.nvfetcher}/bin/nvfetcher -c nvfetcher.toml -o _sources
                ''
              );
            };
          };
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-rfc-style
              nil
              statix
            ];
          };
        };

      flake =
        {
          withSystem,
          inputs,
          lib,
          ...
        }:
        {
          # Put your original flake attributes here.
          overlays = {
            default = import ./overlay.nix { inherit lib inputs; };
            nixops-fix = ./pkgs/nixops-fixed/poetry-git-overlay.nix;
          };
          nixosModules = import ./modules;
          templates = import ./templates;
        };
    };
}
