{
  description = "My personal NUR repository";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";

  };
  outputs = { self, nixpkgs, flake-parts, dream2nix, pkgs-by-name-for-flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ inputs, ... }: 
    {
      
      imports = [
        inputs.pkgs-by-name-for-flake-parts.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, lib, ... }:
        {
          pkgsDirectory = ./pkgs;
          pkgsNameSeparator = "-";
          packages = import ./. {
            inherit self lib pkgs;
          };
          apps = {
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
              nixd
              statix
            ];
          };
        };

      flake = {
        overlays.default = _final: prev:
          let
            isReserved = n: n == "lib" || n == "overlays" || n == "modules";
            nameValuePair = n: v: {
              name = n;
              value = v;
            };
            nurAttrs = self.packages.x86_64-linux;
          in builtins.listToAttrs (map (n: nameValuePair n nurAttrs.${n})
            (builtins.filter (n: !isReserved n) (builtins.attrNames nurAttrs)));       
    
        nixosModules = import ./modules;
        templates = import ./templates;
      };
    });
}
